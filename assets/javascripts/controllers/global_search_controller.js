import { Controller } from '@hotwired/stimulus';

const MAX_HISTORY_ENTRIES = 15;
const HISTORY_STORAGE_KEY = 'global_search_history';

class GlobalSearchController extends Controller {
  static values = {
    url: String,
    projectId: String,
    projectName: String
  };

  static targets = ['input', 'results', 'hint', 'scopePanel', 'scopeBadge'];

  connect() {
    this.selectedIndex = -1;
    this.initScope();
    this.debounceTimer = null;
    this.abortController = null;
    this.lastQuery = '';
    this.hasResults = false;

    this.i18n = {
      noResults: this.element.dataset.noResults || 'No results',
      hint: this.element.dataset.hint || 'Type to search...',
      loading: this.element.dataset.loading || 'Searching...',
      recentSearches: this.element.dataset.recentSearches || 'Recently searched',
      recentProjects: this.element.dataset.recentProjects || 'Recently used projects',
      clearAll: this.element.dataset.clearAll || 'Clear all'
    };

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

    if (this.hasInputTarget) {
      this.inputTarget.value = query || '';
      this.inputTarget.focus();
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

    clearTimeout(this.debounceTimer);

    if (query.length < 2) {
      this.loadInitialContent();
      this.lastQuery = query;
      return;
    }

    if (query === this.lastQuery) {
      return;
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query);
    }, 300);
  }

  async performSearch(query) {
    this.cancelPending();
    this.setLoading(true);
    this.lastQuery = query;

    this.abortController = new AbortController();
    const params = new URLSearchParams({ q: query });

    const projectId = this.effectiveProjectId();
    if (projectId) {
      params.set('project_id', projectId);
    }

    const searchScope = this.effectiveSearchScope();
    if (searchScope) {
      params.set('scope', searchScope);
    }

    const url = `${this.urlValue}?${params}`;

    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': AdditionalsHelpers.csrfToken(),
          'X-Requested-With': 'XMLHttpRequest'
        },
        signal: this.abortController.signal
      });

      if (!response.ok) {
        this.showHint(this.i18n.noResults);
        return;
      }

      const data = await response.json();
      this.setLoading(false);
      this.renderResults(data, query);
    } catch (error) {
      this.setLoading(false);
      if (error.name !== 'AbortError') {
        this.showHint(this.i18n.noResults);
      }
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

    this.abortController = new AbortController();

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
        signal: this.abortController.signal
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
    }
  }

  // -- Rendering --

  renderResults(data, query) {
    if (!this.hasResultsTarget) {
      return;
    }

    const { semantic } = data;
    const keyword = data.keyword || [];
    const hasKeyword = keyword.length > 0;
    const hasSemantic = semantic && semantic.results && semantic.results.length > 0;

    this.hasResults = hasKeyword || hasSemantic;
    this.hideHint();
    let html = '';

    if (query) {
      html += this.renderCoreSearchLink(query);
    }

    if (!hasKeyword && !hasSemantic && query) {
      html += `<p class="global-search-no-results">${this.escapeHtml(this.i18n.noResults)}</p>`;
      this.resultsTarget.innerHTML = html;
      this.selectedIndex = -1;
      return;
    }

    for (const item of keyword) {
      html += this.renderItem(item, query);
    }

    if (hasSemantic) {
      const semanticIcon = this.element.dataset.semanticIcon || '';
      html += '<div class="global-search-section-header global-search-semantic-header">'
        + `<span>${semanticIcon} ${this.escapeHtml(semantic.label)}</span></div>`;
      for (const item of semantic.results) {
        html += this.renderItem(item, query);
      }
    }

    this.resultsTarget.innerHTML = html;
    this.selectedIndex = -1;
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

  renderCoreSearchLink(query) {
    const coreUrl = this.element.dataset.coreSearchUrl;
    if (!coreUrl) {
      return '';
    }

    const safeQuery = this.escapeHtml(query);
    const searchLabel = this.element.dataset.searchLabel || 'Search';
    const url = `${this.escapeHtml(coreUrl)}?q=${encodeURIComponent(query)}`;

    return '<div class="global-search-core-link">'
      + `<a href="${url}" class="global-search-item">`
      + `<span class="global-search-item-title">${this.escapeHtml(searchLabel)} <strong>${safeQuery}</strong></span>`
      + '</a></div>';
  }


  renderItem(item, query) {
    const safeTitle = this.highlightMatch(this.escapeHtml(item.title), query);
    const safeUrl = this.escapeHtml(item.url);

    let html = `<a href="${safeUrl}" class="global-search-item">`;
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

    const safeQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(`(${safeQuery})`, 'gi');
    return escapedText.replace(regex, '<mark>$1</mark>');
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
    this.performSearch(term);
  }

  // -- Result click handling --

  onResultClick(event) {
    const item = event.target.closest('.global-search-item');
    if (item && item.getAttribute('href')) {
      this.saveCurrentQuery();
    }
  }

  // -- Selection navigation --

  get selectableItems() {
    return this.hasResultsTarget
      ? Array.from(this.resultsTarget.querySelectorAll('.global-search-item'))
      : [];
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
    if (this.selectedIndex >= 0 && this.selectedIndex < items.length) {
      const selected = items[this.selectedIndex];

      // Handle history term selection via Enter
      const { searchTerm } = selected.dataset;
      if (searchTerm) {
        if (this.hasInputTarget) {
          this.inputTarget.value = searchTerm;
        }
        this.performSearch(searchTerm);
        return;
      }

      const href = selected.getAttribute('href');
      if (href) {
        this.saveCurrentQuery();
        window.location.href = href;
      }
    }
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

      const isMac = navigator.platform.indexOf('Mac') > -1;
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
    this.updateScopeBadge();
  }

  persistentScopes = ['always_global', 'always_bookmarks'];

  toggleScopePanel() {
    if (!this.hasScopePanelTarget) {
      return;
    }
    const visible = this.scopePanelTarget.style.display !== 'none';
    this.scopePanelTarget.style.display = visible ? 'none' : '';
  }

  onScopeChange(event) {
    this.currentScope = event.target.value;

    if (this.persistentScopes.includes(this.currentScope)) {
      localStorage.setItem('global_search_scope', this.currentScope);
    } else {
      localStorage.removeItem('global_search_scope');
    }

    this.scopePanelTarget.style.display = 'none';
    this.updateScopeBadge();
    this.initialData = null;

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
      always_bookmarks: 'bookmarks'
    };
    return scopeMap[this.currentScope] || null;
  }

  updateScopeBadge() {
    if (!this.hasScopeBadgeTarget) {
      return;
    }

    const badgeLabels = {
      global: 'Global',
      always_global: 'Global',
      bookmarks: this.element.dataset.bookmarksLabel || 'Bookmarks',
      always_bookmarks: this.element.dataset.bookmarksLabel || 'Bookmarks'
    };

    const label = badgeLabels[this.currentScope];
    if (label) {
      this.scopeBadgeTarget.style.display = '';
      this.scopeBadgeTarget.textContent = label;
    } else {
      this.scopeBadgeTarget.style.display = 'none';
    }
  }

  updateScopeRadios() {
    const radios = this.element.querySelectorAll('input[name="global-search-scope"]');
    for (const radio of radios) {
      radio.checked = radio.value === this.currentScope;
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
  }

  escapeHtml(str) {
    if (typeof sanitizeHTML === 'function') {
      return sanitizeHTML(str);
    }
    const el = document.createElement('span');
    el.textContent = String(str);
    return el.innerHTML;
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('global-search', GlobalSearchController);
}

export default GlobalSearchController;
