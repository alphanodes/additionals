import { Controller } from '@hotwired/stimulus';

const MAX_HISTORY_ENTRIES = 15;
const HISTORY_STORAGE_KEY = 'global_search_history';
const KEYWORD_DEBOUNCE_MS = 300;
// Semantic results cost a request to an external AI provider, and the server serializes
// those. Waiting until typing has settled keeps intermediate input from occupying the slot.
const SEMANTIC_DEBOUNCE_MS = 800;
const ID_REFERENCE = /^#\d+$/;
const HTML_ENTITY = '&(?:#\\d+|\\w+);';

// Escapes quotes as well: values also land in attributes (href, data-search-term), where
// Redmine's sanitizeHTML leaves a quote free to end the attribute.
function escapeHtml(str) {
  if (str === null || str === undefined) {
    return '';
  }
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

class GlobalSearchController extends Controller {
  static values = {
    url: String,
    projectId: String,
    projectName: String,
  };

  static targets = ['input', 'results', 'hint', 'scopePanel', 'clearButton', 'titlesOnly'];

  connect() {
    this.selectedIndex = -1;
    this.debounceTimer = null;
    this.abortController = null;
    this.semanticTimer = null;
    this.semanticAbortController = null;
    this.semanticRequest = null;
    this.searchGeneration = 0;
    this.lastInputAt = 0;
    this.pendingJump = null;
    this.keywordUrls = new Set();
    this.lastQuery = '';
    this.hasResults = false;

    this.i18n = {
      noResults: this.element.dataset.noResults || 'No results',
      hint: this.element.dataset.hint || 'Type to search...',
      loading: this.element.dataset.loading || 'Searching...',
      recentSearches: this.element.dataset.recentSearches || 'Recently searched',
      recentProjects: this.element.dataset.recentProjects || 'Recently used projects',
      clearAll: this.element.dataset.clearAll || 'Clear all',
    };

    this.defaultPlaceholder = this.hasInputTarget ? this.inputTarget.placeholder : '';
    this.activeSearchType = null;
    this.titlesOnlyActive = false;
    this.initScope();
    this.initTitlesOnly();

    this.boundOnKeydown = this.onGlobalKeydown.bind(this);
    this.boundInterceptSearch = this.interceptQuickSearch.bind(this);

    document.addEventListener('keydown', this.boundOnKeydown);
    this.interceptHeaderSearch();
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundOnKeydown);
    this.restoreHeaderSearch();
    this.cancelPending();
  }

  // -- Open / Close --

  open(query) {
    this.element.classList.add('active');
    this.selectedIndex = -1;
    this.lastQuery = '';
    this.hasResults = false;
    this.activeSearchType = null;
    this.typeCounts = null;
    this.typeCountsQuery = null;

    if (this.hasInputTarget) {
      this.inputTarget.value = query || '';
      // Defer focus until after the display:none -> display:flex paint, so the
      // browser's compositor sets up the caret layer and the cursor is visible.
      requestAnimationFrame(() => this.inputTarget.focus());
      this.toggleClearButton(Boolean(query));
    }

    if (query && query.length >= 2) {
      this.performSearch(query);
    } else {
      this.loadInitialContent();
    }
  }

  close() {
    this.saveCurrentQuery();
    this.element.classList.remove('active');
    this.cancelPending();
    this.selectedIndex = -1;
  }

  closeOnOverlay(event) {
    if (event.target === this.element) {
      this.close();
    }
  }

  // -- Keyboard --

  onGlobalKeydown(event) {
    const isMod = event.metaKey || event.ctrlKey;

    if (isMod && event.key === 'k') {
      event.preventDefault();
      if (this.element.classList.contains('active')) {
        this.close();
      } else {
        const urlQuery = new URLSearchParams(window.location.search).get('q');
        this.open(urlQuery || undefined);
      }
      return;
    }

    if (!this.element.classList.contains('active')) {
      return;
    }

    if (event.key === 'Escape') {
      event.preventDefault();
      this.close();
      return;
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      this.moveSelection(1);
      return;
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault();
      this.moveSelection(-1);
      return;
    }

    if (event.key === 'Enter') {
      event.preventDefault();
      this.openSelected();
    }
  }

  // -- Search --

  onInput() {
    const query = this.hasInputTarget ? this.inputTarget.value.trim() : '';

    this.closeScopePanel();
    this.lastInputAt = Date.now();
    this.toggleClearButton(query.length > 0);
    clearTimeout(this.debounceTimer);

    if (query.length < 2) {
      this.loadInitialContent();
      this.lastQuery = query;
      return;
    }

    // Typing that does not change the query (a trailing space) keeps its results, but
    // still counts as typing for a semantic search that has not started yet.
    if (query === this.lastQuery) {
      this.rescheduleSemanticSearch();
      return;
    }

    // The shown results belong to the previous query: Enter must not open their selection,
    // and their semantic search waits for typing to settle again. The keyword search
    // replaces both once it starts.
    this.pendingJump = null;
    this.clearSelection();
    this.rescheduleSemanticSearch();
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query);
    }, KEYWORD_DEBOUNCE_MS);
  }

  async performSearch(query) {
    this.cancelPending();
    this.setLoading(true);
    this.lastQuery = query;
    const generation = this.searchGeneration;

    const abortController = new AbortController();
    this.abortController = abortController;
    const params = new URLSearchParams({ q: query });

    const projectId = this.effectiveProjectId();
    if (projectId) {
      params.set('project_id', projectId);
    }

    const searchScope = this.effectiveSearchScope();
    if (searchScope) {
      params.set('scope', searchScope);
    }

    if (this.activeSearchType) {
      params.set('types[]', this.activeSearchType);
    }

    if (this.titlesOnlyActive) {
      params.set('titles_only', '1');
    }

    const url = `${this.urlValue}?${params}`;

    try {
      const response = await fetch(url, {
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': AdditionalsHelpers.csrfToken(),
          'X-Requested-With': 'XMLHttpRequest',
        },
        signal: abortController.signal,
      });

      if (!response.ok) {
        this.pendingJump = null;
        this.setLoading(false);
        this.removeSemanticSection();
        this.showHint(this.i18n.noResults);
        return;
      }

      const data = await response.json();
      if (generation !== this.searchGeneration) {
        return;
      }

      this.setLoading(false);
      this.renderResults(data, query);

      const keywordCount = (data.keyword || []).length;
      if (data.jump && keywordCount > 0 && this.pendingJump === query) {
        this.saveCurrentQuery();
        window.location.href = data.keyword[0].url;
        return;
      }

      this.pendingJump = null;
      if (!data.jump) {
        this.scheduleSemanticSearch(query, keywordCount, generation);
      }
    } catch (error) {
      // A search that was superseded leaves the loading state to its successor.
      if (this.abortController === abortController) {
        this.setLoading(false);
      }
      if (error.name !== 'AbortError') {
        this.pendingJump = null;
        this.removeSemanticSection();
        this.showHint(this.i18n.noResults);
      }
    } finally {
      if (this.abortController === abortController) {
        this.abortController = null;
      }
    }
  }

  // -- Semantic search --

  semanticTypes() {
    try {
      const types = JSON.parse(this.element.dataset.semanticTypes || '[]');
      return Array.isArray(types) ? types : [];
    } catch {
      return [];
    }
  }

  semanticApplies(query, keywordCount) {
    if (!this.element.dataset.semanticUrl || !query || ID_REFERENCE.test(query)) {
      return false;
    }
    // The server skips a bare number the keyword search did not find, so there is
    // nothing to wait for.
    if (keywordCount === 0 && /^\d+$/.test(query)) {
      return false;
    }

    const types = this.semanticTypes();
    if (types.length === 0) {
      return false;
    }
    return !this.activeSearchType || types.includes(this.activeSearchType);
  }

  scheduleSemanticSearch(query, keywordCount, generation) {
    if (!this.semanticApplies(query, keywordCount)) {
      return;
    }

    this.semanticRequest = { query, keywordCount, generation };
    const delay = Math.max(0, SEMANTIC_DEBOUNCE_MS - (Date.now() - this.lastInputAt));
    this.semanticTimer = setTimeout(() => {
      this.semanticTimer = null;
      this.performSemanticSearch(query, keywordCount, generation);
    }, delay);
  }

  rescheduleSemanticSearch() {
    if (!this.semanticTimer || !this.semanticRequest) {
      return;
    }

    clearTimeout(this.semanticTimer);
    this.semanticTimer = null;
    const { query, keywordCount, generation } = this.semanticRequest;
    this.scheduleSemanticSearch(query, keywordCount, generation);
  }

  async performSemanticSearch(query, keywordCount, generation) {
    const abortController = new AbortController();
    this.semanticAbortController = abortController;
    const params = new URLSearchParams({ q: query, keyword_hits: String(keywordCount) });

    const projectId = this.effectiveProjectId();
    if (projectId) {
      params.set('project_id', projectId);
    }

    const searchScope = this.effectiveSearchScope();
    if (searchScope) {
      params.set('scope', searchScope);
    }

    if (this.activeSearchType) {
      params.set('types[]', this.activeSearchType);
    }

    let data = null;
    try {
      const response = await fetch(`${this.element.dataset.semanticUrl}?${params}`, {
        headers: {
          Accept: 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        signal: abortController.signal,
      });
      if (response.ok) {
        data = await response.json();
      }
    } catch (error) {
      if (error.name === 'AbortError') {
        return;
      }
    } finally {
      if (this.semanticAbortController === abortController) {
        this.semanticAbortController = null;
      }
    }

    this.renderSemanticResults(data, query, generation);
  }

  renderSemanticResults(data, query, generation) {
    if (generation !== this.searchGeneration || !this.hasResultsTarget) {
      return;
    }

    const section = this.resultsTarget.querySelector('[data-semantic-section]');
    if (!section) {
      return;
    }

    // Deduplicate over the url: an id alone is not unique across types, and a provider may
    // identify a record differently than the keyword search does.
    const results = (data?.results || []).filter(item => !this.keywordUrls.has(item.url));
    if (results.length === 0) {
      if (!this.hasResults) {
        section.insertAdjacentHTML('beforebegin', this.renderNoResults());
      }
      section.remove();
      return;
    }

    let html = this.renderSemanticHeader(data.label);
    for (const item of results) {
      html += this.renderItem(item, query);
    }
    section.innerHTML = html;
    this.hasResults = true;
  }

  cancelSemantic() {
    clearTimeout(this.semanticTimer);
    this.semanticTimer = null;
    if (this.semanticAbortController) {
      this.semanticAbortController.abort();
      this.semanticAbortController = null;
    }
  }

  // An id reference (#1234) opens its first hit on Enter. If Enter comes before the
  // results, the jump happens as soon as they arrive.
  jumpWhenReady() {
    const query = this.hasInputTarget ? this.inputTarget.value.trim() : '';
    if (!ID_REFERENCE.test(query)) {
      return;
    }

    // performSearch clears pendingJump, so it is set afterwards. The request is still open
    // then: fetch never resolves before the first await.
    if (query !== this.lastQuery) {
      this.performSearch(query);
      this.pendingJump = query;
    } else if (this.abortController) {
      this.pendingJump = query;
    }
  }

  async loadInitialContent() {
    this.cancelPending();
    this.selectedIndex = -1;
    this.hasResults = false;

    if (this.initialData) {
      this.renderInitialContent(this.initialData);
      return;
    }

    this.hideHint();
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = '';
    }

    const abortController = new AbortController();
    this.abortController = abortController;

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        signal: abortController.signal,
      });

      if (!response.ok) {
        return;
      }

      const data = await response.json();
      this.initialData = data;
      this.renderInitialContent(data);
    } catch (error) {
      if (error.name !== 'AbortError') {
        this.showHint(this.i18n.hint);
      }
    } finally {
      // jumpWhenReady reads a set abortController as "a request is open".
      if (this.abortController === abortController) {
        this.abortController = null;
      }
    }
  }

  // -- Rendering --

  renderResults(data, query) {
    if (!this.hasResultsTarget) {
      return;
    }

    const keyword = data.keyword || [];
    const hasKeyword = keyword.length > 0;

    // A filtered answer only counts the type it was filtered to. As long as the query stays
    // the same, the counts of the unfiltered search are kept, so switching tabs does not make
    // the others disappear. For a new query they are gone: the dialog then shows the active
    // tab with its own number and "all" to get back, rather than numbers of the query before.
    if (!this.activeSearchType || this.typeCountsQuery !== query) {
      this.typeCounts = data.counts || {};
      this.typeCountsQuery = query;
    }
    const semanticPending = !data.jump && this.semanticApplies(query, keyword.length);

    this.keywordUrls = new Set(keyword.map(item => item.url));
    this.hasResults = hasKeyword;
    this.hideHint();
    let html = '';

    if (query) {
      html += this.renderSearchTypeTabs();
      html += this.renderCoreSearchLink(query);
    }

    if (!hasKeyword && !semanticPending && query) {
      html += this.renderNoResults();
      this.resultsTarget.innerHTML = html;
      this.selectedIndex = -1;
      return;
    }

    keyword.forEach((item, index) => {
      html += this.renderItem(item, query, { jumpTarget: Boolean(data.jump) && index === 0 });
    });

    if (semanticPending) {
      const header = this.renderSemanticHeader(this.element.dataset.semanticLabel);
      const loading = `<p class="global-search-semantic-loading">${this.escapeHtml(this.i18n.loading)}</p>`;
      html += `<div class="global-search-semantic" data-semantic-section>${header}${loading}</div>`;
    }

    html += this.renderAllResultsLink(query, keyword.length);

    this.resultsTarget.innerHTML = html;
    this.selectedIndex = -1;

    if (data.jump) {
      this.selectJumpTarget();
    }
  }

  renderSemanticHeader(label) {
    const semanticIcon = this.element.dataset.semanticIcon || '';
    return '<div class="global-search-section-header global-search-semantic-header">' +
      `<span>${semanticIcon} ${this.escapeHtml(label || '')}</span></div>`;
  }

  renderNoResults() {
    return `<p class="global-search-no-results">${this.escapeHtml(this.i18n.noResults)}</p>`;
  }

  clearSelection() {
    this.selectedIndex = -1;
    if (!this.hasResultsTarget) {
      return;
    }
    for (const item of this.resultsTarget.querySelectorAll('.global-search-item.selected')) {
      item.classList.remove('selected');
    }
    for (const shortcut of this.resultsTarget.querySelectorAll('.global-search-item-shortcut')) {
      shortcut.remove();
    }
  }

  removeSemanticSection() {
    this.resultsTarget?.querySelector('[data-semantic-section]')?.remove();
  }

  selectJumpTarget() {
    const items = this.selectableItems;
    const index = items.findIndex(item => item.hasAttribute('data-jump-target'));
    if (index >= 0) {
      this.selectedIndex = index;
      items[index].classList.add('selected');
    }
  }

  renderInitialContent(data) {
    if (!this.hasResultsTarget) {
      return;
    }

    const history = this.getSearchHistory();
    const projects = data.keyword || [];

    if (history.length === 0 && projects.length === 0) {
      this.showHint(this.i18n.hint);
      return;
    }

    this.hideHint();
    let html = '';

    if (history.length > 0) {
      html += this.renderHistorySection(history);
    }

    if (projects.length > 0) {
      html += `<div class="global-search-section-header"><span>${this.escapeHtml(this.i18n.recentProjects)}</span></div>`;
      for (const item of projects) {
        html += this.renderItem(item, '');
      }
    }

    this.resultsTarget.innerHTML = html;
    this.selectedIndex = -1;
  }

  renderHistorySection(history) {
    let html = '<div class="global-search-history-section">';
    html += '<div class="global-search-section-header">';
    html += `<span>${this.escapeHtml(this.i18n.recentSearches)}</span>`;
    html += `<a href="#" class="global-search-clear-link" data-action="click->global-search#clearHistory">${this.escapeHtml(this.i18n.clearAll)}</a>`;
    html += '</div>';

    for (const term of history) {
      html += `<a class="global-search-item global-search-history-item" data-search-term="${this.escapeHtml(term)}" data-action="click->global-search#onHistoryTermClick">`;
      html += `<span class="global-search-item-title">${this.escapeHtml(term)}</span>`;
      html += '</a>';
    }

    html += '</div>';
    return html;
  }

  // The dialog searches the project while its scope says so, and then the link has to lead
  // there as well: a count taken in the project next to a link into the global search
  // contradicts itself.
  coreSearchParams(query) {
    const params = new URLSearchParams({ q: query });
    const coreScope = this.coreSearchScope();
    if (coreScope) {
      params.set('scope', coreScope);
    }
    if (this.currentScope === 'project' && this.projectIdValue) {
      params.set('project_id', this.projectIdValue);
    }
    if (this.titlesOnlyActive) {
      params.set('titles_only', '1');
    }
    if (this.activeSearchType) {
      params.set(this.activeSearchType, '1');
    }

    return params;
  }

  renderCoreSearchLink(query) {
    const coreUrl = this.element.dataset.coreSearchUrl;
    if (!coreUrl) {
      return '';
    }

    const safeQuery = this.escapeHtml(query);
    const searchLabel = this.element.dataset.searchLabel || 'Search';
    const titlesPrefix = this.titlesOnlyActive
      ? (this.element.dataset.titlesOnlyPrefix || 'in titles')
      : null;
    const suffix = this.scopeSuffix();
    let scopeText = '';
    if (titlesPrefix && suffix) {
      scopeText = ` ${this.escapeHtml(titlesPrefix)} ${this.escapeHtml(suffix)}`;
    } else if (titlesPrefix) {
      scopeText = ` ${this.escapeHtml(titlesPrefix)}`;
    } else if (suffix) {
      scopeText = ` ${this.escapeHtml(suffix)}`;
    }
    const url = `${this.escapeHtml(coreUrl)}?${this.coreSearchParams(query)}`;

    return '<div class="global-search-core-link">' +
      `<a href="${url}" class="global-search-item">` +
      `<span class="global-search-item-title">${this.escapeHtml(searchLabel)} <strong>${safeQuery}</strong>${scopeText}</span>` +
      '</a></div>';
  }

  // Closes the list when the core search holds more than it shows. With every hit already
  // listed the link would promise something that is not there, so it stays away.
  renderAllResultsLink(query, shown) {
    const coreUrl = this.element.dataset.coreSearchUrl;
    const total = this.hitsBehindTheLink();
    if (!query || !coreUrl || total <= shown) {
      return '';
    }

    // The number sits inside the sentence, so each language can place it where it belongs
    const label = (this.element.dataset.allResults || 'All %{count} results').replace('%{count}', total);

    return '<div class="global-search-all-results">' +
      `<a href="${this.escapeHtml(coreUrl)}?${this.coreSearchParams(query)}" class="global-search-item">` +
      `<span class="global-search-item-title">${this.escapeHtml(label)}</span>` +
      '</a></div>';
  }

  // How many hits the core search behind the link holds: the ones of the active tab, or all
  // of them. The dialog only ever shows ten, so without the number nothing says there is more.
  hitsBehindTheLink() {
    if (!this.typeCounts) {
      return 0;
    }
    if (this.activeSearchType) {
      return this.typeCounts[this.activeSearchType] || 0;
    }

    return Object.values(this.typeCounts).reduce((sum, value) => sum + value, 0);
  }

  renderItem(item, query, { jumpTarget = false } = {}) {
    const safeTitle = this.highlightMatch(this.escapeHtml(item.title), query);
    const safeUrl = this.escapeHtml(item.url);

    let html = jumpTarget
      ? `<a href="${safeUrl}" class="global-search-item" data-jump-target><kbd class="global-search-item-shortcut">Enter</kbd>`
      : `<a href="${safeUrl}" class="global-search-item">`;
    html += `<span class="global-search-item-title">${safeTitle}</span>`;

    let meta = '';
    if (item.type) {
      meta += `<span class="global-search-item-type">${this.escapeHtml(item.type)}</span>`;
    }
    if (item.project_name) {
      meta += `<span class="global-search-item-project">${this.escapeHtml(item.project_name)}</span>`;
    }
    if (meta) {
      html += `<span class="global-search-item-meta">${meta}</span>`;
    }

    html += '</a>';
    return html;
  }

  highlightMatch(escapedText, query) {
    if (!query) {
      return escapedText;
    }

    // The text is escaped, so the query is matched in its escaped form. An entity is
    // consumed as a whole first: a query like "quot" must not cut into "&quot;".
    const safeQuery = escapeHtml(query).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`(${safeQuery})|${HTML_ENTITY}`, 'gi');
    return escapedText.replace(regex, (match, hit) => (hit ? `<mark>${hit}</mark>` : match));
  }

  // -- Search history --

  getSearchHistory() {
    try {
      const data = localStorage.getItem(HISTORY_STORAGE_KEY);
      if (!data) {
        return [];
      }

      const parsed = JSON.parse(data);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  saveCurrentQuery() {
    if (!this.hasResults) {
      return;
    }

    const query = this.hasInputTarget ? this.inputTarget.value.trim() : '';
    if (query.length < 2) {
      return;
    }

    const history = this.getSearchHistory();
    const filtered = history.filter(term => term.toLowerCase() !== query.toLowerCase());
    filtered.unshift(query);

    try {
      localStorage.setItem(HISTORY_STORAGE_KEY, JSON.stringify(filtered.slice(0, MAX_HISTORY_ENTRIES)));
    } catch {
      // localStorage full or unavailable
    }
  }

  clearHistory(event) {
    event.preventDefault();

    try {
      localStorage.removeItem(HISTORY_STORAGE_KEY);
    } catch {
      // localStorage unavailable
    }

    const section = this.resultsTarget.querySelector('.global-search-history-section');
    if (section) {
      section.remove();
    }
  }

  onHistoryTermClick(event) {
    event.preventDefault();

    const item = event.target.closest('[data-search-term]');
    if (!item) {
      return;
    }

    const term = item.dataset.searchTerm;
    if (this.hasInputTarget) {
      this.inputTarget.value = term;
    }
    this.toggleClearButton(true);
    this.performSearch(term);
  }

  // -- Result click handling --

  onResultClick(event) {
    const item = event.target.closest('.global-search-item');
    if (item && item.getAttribute('href')) {
      item.classList.add('selected');
      this.saveCurrentQuery();
    }
  }

  // -- Selection navigation --

  // The link to the core search at the top is not part of the selection: Enter belongs to the
  // best hit. The one closing the list is, it is the last thing one arrives at.
  get selectableItems() {
    if (!this.hasResultsTarget) {
      return [];
    }

    return Array.from(this.resultsTarget.querySelectorAll('.global-search-item'))
      .filter(item => !item.closest('.global-search-core-link'));
  }

  moveSelection(direction) {
    const items = this.selectableItems;
    if (items.length === 0) {
      return;
    }

    // Remove current highlight
    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
      items[this.selectedIndex].classList.remove('selected');
    }

    this.selectedIndex += direction;

    if (this.selectedIndex < 0) {
      this.selectedIndex = items.length - 1;
    } else if (this.selectedIndex >= items.length) {
      this.selectedIndex = 0;
    }

    items[this.selectedIndex].classList.add('selected');
    items[this.selectedIndex].scrollIntoView({ block: 'nearest' });
  }

  openSelected() {
    const items = this.selectableItems;
    // Enter without having moved the selection opens the best hit, which is the first of the
    // list. Without hits it stays with the jump of an id reference.
    const index = this.selectedIndex >= 0 ? this.selectedIndex : this.firstHitIndex();

    if (index >= 0 && index < items.length) {
      const selected = items[index];

      // Handle history term selection via Enter
      const { searchTerm } = selected.dataset;
      if (searchTerm) {
        if (this.hasInputTarget) {
          this.inputTarget.value = searchTerm;
        }
        this.toggleClearButton(true);
        this.performSearch(searchTerm);
        return;
      }

      const href = selected.getAttribute('href');
      if (href) {
        this.saveCurrentQuery();
        window.location.href = href;
      }
      return;
    }

    this.jumpWhenReady();
  }

  // Only while the list holds the hits of what stands in the field right now: the initial view
  // lists earlier searches, which Enter is not meant to repeat by itself, and after typing on
  // the hits still shown belong to the query before (see the id reference tests).
  firstHitIndex() {
    const query = this.hasInputTarget ? this.inputTarget.value.trim() : '';

    return this.hasResults && query === this.lastQuery ? 0 : -1;
  }

  // -- Header search interception --

  interceptHeaderSearch() {
    const quickSearch = document.getElementById('quick-search');
    if (!quickSearch) {
      return;
    }

    const searchInput = quickSearch.querySelector('input[name="q"]');
    if (searchInput) {
      searchInput.addEventListener('focus', this.boundInterceptSearch);

      const isMac = navigator.userAgentData?.platform === 'macOS' || /Mac/.test(navigator.userAgent);
      const shortcut = isMac ? '\u2318K' : 'Ctrl+K';
      const searchLabel = this.element.dataset.searchLabel || 'Search';
      searchInput.setAttribute('placeholder', `${searchLabel} ${shortcut}`);
    }
  }

  restoreHeaderSearch() {
    const quickSearch = document.getElementById('quick-search');
    if (!quickSearch) {
      return;
    }

    const searchInput = quickSearch.querySelector('input[name="q"]');
    if (searchInput) {
      searchInput.removeEventListener('focus', this.boundInterceptSearch);
    }
  }

  interceptQuickSearch(event) {
    event.preventDefault();
    const query = event.target.value.trim();
    event.target.blur();
    this.open(query);
  }

  // -- Scope --

  initScope() {
    const stored = localStorage.getItem('global_search_scope');
    this.currentScope = stored || (this.projectIdValue ? 'project' : 'global');
    this.updateScopeRadios();
    this.updatePlaceholder();
  }

  persistentScopes = ['always_global', 'always_bookmarks'];

  toggleScopePanel() {
    if (!this.hasScopePanelTarget) {
      return;
    }
    const visible = this.scopePanelTarget.style.display !== 'none';
    this.scopePanelTarget.style.display = visible ? 'none' : '';
  }

  // Opened just to look up the current scope, the panel covers the results and has no way out
  // of its own: the options are radio buttons, so clicking the one already selected does
  // nothing. Every search closes it, which is what one does next anyway.
  closeScopePanel() {
    if (this.hasScopePanelTarget) {
      this.scopePanelTarget.style.display = 'none';
    }
  }

  onScopeChange(event) {
    this.currentScope = event.target.value;

    if (this.persistentScopes.includes(this.currentScope)) {
      localStorage.setItem('global_search_scope', this.currentScope);
    } else {
      localStorage.removeItem('global_search_scope');
    }

    this.closeScopePanel();
    this.updatePlaceholder();
    this.initialData = null;
    this.lastInputAt = Date.now();
    this.validateActiveSearchType();

    // Re-run search with new scope
    if (this.hasInputTarget && this.inputTarget.value.trim().length >= 2) {
      this.performSearch(this.inputTarget.value.trim());
    } else {
      this.loadInitialContent();
    }
  }

  effectiveProjectId() {
    if (this.currentScope !== 'project') {
      return null;
    }
    return this.projectIdValue || null;
  }

  effectiveSearchScope() {
    const scopeMap = {
      bookmarks: 'bookmarks',
      always_bookmarks: 'bookmarks',
    };
    return scopeMap[this.currentScope] || null;
  }

  coreSearchScope() {
    const scopeMap = {
      global: 'all',
      always_global: 'all',
      bookmarks: 'bookmarks',
      always_bookmarks: 'bookmarks',
    };
    return scopeMap[this.currentScope] || null;
  }

  scopeSuffix() {
    const { dataset } = this.element;
    const suffixes = {
      global: dataset.scopeAll,
      always_global: dataset.scopeAll,
      bookmarks: dataset.scopeBookmarks,
      always_bookmarks: dataset.scopeBookmarks,
    };
    return suffixes[this.currentScope] || null;
  }

  updatePlaceholder() {
    if (!this.hasInputTarget) {
      return;
    }

    const suffix = this.scopeSuffix();
    const titlesPrefix = this.titlesOnlyActive
      ? (this.element.dataset.titlesOnlyPrefix || 'in titles')
      : null;
    const searchLabel = this.element.dataset.searchLabel || 'Search';

    if (titlesPrefix && suffix) {
      this.inputTarget.placeholder = `${searchLabel} ${titlesPrefix} ${suffix}...`;
    } else if (titlesPrefix) {
      this.inputTarget.placeholder = `${searchLabel} ${titlesPrefix}...`;
    } else if (suffix) {
      this.inputTarget.placeholder = `${searchLabel} ${suffix}...`;
    } else {
      this.inputTarget.placeholder = this.defaultPlaceholder;
    }
  }

  updateScopeRadios() {
    const radios = this.element.querySelectorAll('input[name="global-search-scope"]');
    for (const radio of radios) {
      radio.checked = radio.value === this.currentScope;
    }
  }

  // -- Titles only --

  initTitlesOnly() {
    if (this.hasTitlesOnlyTarget) {
      this.titlesOnlyTarget.checked = this.titlesOnlyActive;
    }
  }

  onTitlesOnlyChange(event) {
    this.titlesOnlyActive = event.target.checked;
    this.lastInputAt = Date.now();
    this.closeScopePanel();
    this.updatePlaceholder();

    if (this.hasInputTarget && this.inputTarget.value.trim().length >= 2) {
      this.performSearch(this.inputTarget.value.trim());
    }
  }

  // -- Clear input --

  clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = '';
      this.inputTarget.focus();
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.scrollTop = 0;
    }
    this.toggleClearButton(false);
    this.loadInitialContent();
  }

  toggleClearButton(visible) {
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.style.display = visible ? '' : 'none';
    }
  }

  // -- Search type tabs --

  getSearchTypes() {
    try {
      const useProjectTypes = this.currentScope === 'project' && this.element.dataset.searchTypesProject;
      const data = useProjectTypes ? this.element.dataset.searchTypesProject : this.element.dataset.searchTypes;
      return JSON.parse(data || '[]');
    } catch {
      return [];
    }
  }

  // A tab for a type without hits leads to an empty list, so only types that answered are
  // offered. Without counts - before the first search - every type stays available.
  typesWithHits() {
    const types = this.getSearchTypes();
    if (!this.typeCounts) {
      return types;
    }

    return types.filter(type => this.typeCounts[type.id]);
  }

  validateActiveSearchType() {
    if (!this.activeSearchType) {
      return;
    }
    const types = this.getSearchTypes();
    if (!types.some(t => t.id === this.activeSearchType)) {
      this.activeSearchType = null;
    }
  }

  onSearchTypeClick(event) {
    event.preventDefault();
    const tab = event.target.closest('[data-type-id]');
    if (!tab) {
      return;
    }

    this.activeSearchType = tab.dataset.typeId || null;
    this.lastInputAt = Date.now();
    this.updateSearchTypeTabs();

    const query = this.hasInputTarget ? this.inputTarget.value.trim() : '';
    if (query.length >= 2) {
      this.performSearch(query);
    }
  }

  renderSearchTypeTabs() {
    const types = this.typesWithHits();
    if (types.length === 0) {
      return '';
    }

    const allLabel = this.element.dataset.tabAll || 'All';
    let html = '<div class="global-search-tabs" data-action="click->global-search#onSearchTypeClick">';
    const allActive = !this.activeSearchType ? ' active' : '';
    html += `<a class="global-search-tab${allActive}" data-type-id="" href="#">${this.escapeHtml(allLabel)}</a>`;

    for (const type of types) {
      const active = this.activeSearchType === type.id ? ' active' : '';
      const count = this.typeCounts?.[type.id];
      const label = count ? `${this.escapeHtml(type.label)} <span class="global-search-tab-count">${count}</span>`
        : this.escapeHtml(type.label);
      html += `<a class="global-search-tab${active}" data-type-id="${this.escapeHtml(type.id)}" href="#">${label}</a>`;
    }

    html += '</div>';
    return html;
  }

  updateSearchTypeTabs() {
    if (!this.hasResultsTarget) {
      return;
    }
    const tabs = this.resultsTarget.querySelectorAll('.global-search-tab');
    for (const tab of tabs) {
      const isActive = (tab.dataset.typeId || null) === (this.activeSearchType || null);
      tab.classList.toggle('active', isActive);
    }
  }

  // -- Helpers --

  setLoading(active) {
    if (this.hasInputTarget) {
      this.inputTarget.classList.toggle('ajax-loading', active);
    }
  }

  showHint(text) {
    if (this.hasHintTarget) {
      this.hintTarget.textContent = text;
      this.hintTarget.style.display = '';
    }
  }

  hideHint() {
    if (this.hasHintTarget) {
      this.hintTarget.style.display = 'none';
    }
  }

  cancelPending() {
    clearTimeout(this.debounceTimer);
    if (this.abortController) {
      this.abortController.abort();
      this.abortController = null;
    }
    this.cancelSemantic();
    this.pendingJump = null;
    this.setLoading(false);
    // Invalidates responses that already arrived but are not rendered yet.
    this.searchGeneration += 1;
  }

  escapeHtml(str) {
    return escapeHtml(str);
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('global-search', GlobalSearchController);
}

export default GlobalSearchController;
