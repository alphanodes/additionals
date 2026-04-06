import { describe, it, expect, beforeEach, vi } from 'vitest';
import GlobalSearchController from '../../../assets/javascripts/controllers/global_search_controller.js';

describe('GlobalSearchController', () => {
  describe('static declarations', () => {
    it('declares expected values', () => {
      expect(GlobalSearchController.values.url).toBe(String);
      expect(GlobalSearchController.values.projectId).toBe(String);
      expect(GlobalSearchController.values.projectName).toBe(String);
    });

    it('declares expected targets', () => {
      expect(GlobalSearchController.targets).toContain('input');
      expect(GlobalSearchController.targets).toContain('results');
      expect(GlobalSearchController.targets).toContain('hint');
      expect(GlobalSearchController.targets).toContain('scopePanel');
      expect(GlobalSearchController.targets).toContain('clearButton');
    });
  });

  describe('open / close', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = `
        <div id="overlay">
          <input id="search-input" type="text" value="old query" />
          <div id="results"><p>stale</p></div>
          <div id="hint">old hint</div>
        </div>
      `;

      ctx = {
        element: document.getElementById('overlay'),
        hasInputTarget: true,
        inputTarget: document.getElementById('search-input'),
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 5,
        lastQuery: 'previous',
        hasResults: false,
        i18n: { hint: 'Type to search...' },
        cancelPending: vi.fn(),
        loadInitialContent: vi.fn(),
        saveCurrentQuery: vi.fn(),
        toggleClearButton: vi.fn()
      };
    });

    it('open adds active class to element', () => {
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.element.classList.contains('active')).toBe(true);
    });

    it('open resets selectedIndex to -1', () => {
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.selectedIndex).toBe(-1);
    });

    it('open clears input value and focuses it', () => {
      const focusSpy = vi.spyOn(ctx.inputTarget, 'focus');
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.inputTarget.value).toBe('');
      expect(focusSpy).toHaveBeenCalled();
    });

    it('open calls loadInitialContent', () => {
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.loadInitialContent).toHaveBeenCalled();
    });

    it('open resets lastQuery', () => {
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.lastQuery).toBe('');
    });

    it('close removes active class from element', () => {
      ctx.element.classList.add('active');
      GlobalSearchController.prototype.close.call(ctx);
      expect(ctx.element.classList.contains('active')).toBe(false);
    });

    it('close calls cancelPending', () => {
      GlobalSearchController.prototype.close.call(ctx);
      expect(ctx.cancelPending).toHaveBeenCalled();
    });

    it('close resets selectedIndex to -1', () => {
      ctx.selectedIndex = 3;
      GlobalSearchController.prototype.close.call(ctx);
      expect(ctx.selectedIndex).toBe(-1);
    });

    it('closeOnOverlay closes when clicking the overlay itself', () => {
      ctx.element.classList.add('active');
      const event = { target: ctx.element };
      // Bind close so closeOnOverlay can call it
      ctx.close = GlobalSearchController.prototype.close.bind(ctx);
      GlobalSearchController.prototype.closeOnOverlay.call(ctx, event);
      expect(ctx.element.classList.contains('active')).toBe(false);
    });

    it('closeOnOverlay does not close when clicking a child', () => {
      ctx.element.classList.add('active');
      const event = { target: ctx.inputTarget };
      ctx.close = GlobalSearchController.prototype.close.bind(ctx);
      GlobalSearchController.prototype.closeOnOverlay.call(ctx, event);
      expect(ctx.element.classList.contains('active')).toBe(true);
    });
  });

  describe('escapeHtml', () => {
    const callEscapeHtml = (str) =>
      GlobalSearchController.prototype.escapeHtml.call({}, str);

    it('escapes HTML angle brackets', () => {
      expect(callEscapeHtml('<script>alert("xss")</script>')).toBe(
        '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'
      );
    });

    it('escapes ampersands', () => {
      expect(callEscapeHtml('foo & bar')).toBe('foo &amp; bar');
    });

    it('escapes double quotes', () => {
      expect(callEscapeHtml('say "hello"')).toBe('say &quot;hello&quot;');
    });

    it('handles null input', () => {
      // sanitizeHTML global returns '' for null
      expect(callEscapeHtml(null)).toBe('');
    });

    it('handles empty string', () => {
      expect(callEscapeHtml('')).toBe('');
    });

    it('returns plain text unchanged', () => {
      expect(callEscapeHtml('hello world')).toBe('hello world');
    });
  });

  describe('highlightMatch', () => {
    const callHighlight = (text, query) =>
      GlobalSearchController.prototype.highlightMatch.call({}, text, query);

    it('wraps matching text in <mark> tags', () => {
      expect(callHighlight('Hello World', 'World')).toBe('Hello <mark>World</mark>');
    });

    it('is case-insensitive', () => {
      expect(callHighlight('Hello World', 'hello')).toBe('<mark>Hello</mark> World');
    });

    it('highlights multiple occurrences', () => {
      expect(callHighlight('foo bar foo', 'foo')).toBe(
        '<mark>foo</mark> bar <mark>foo</mark>'
      );
    });

    it('escapes regex special characters in query', () => {
      // The query "foo.bar" should not match "fooXbar" via regex dot
      expect(callHighlight('foo.bar fooXbar', 'foo.bar')).toBe(
        '<mark>foo.bar</mark> fooXbar'
      );
    });

    it('handles parentheses in query', () => {
      expect(callHighlight('test (value) here', '(value)')).toBe(
        'test <mark>(value)</mark> here'
      );
    });

    it('returns text unchanged when query is empty', () => {
      expect(callHighlight('Hello World', '')).toBe('Hello World');
    });

    it('returns text unchanged when query is null/undefined', () => {
      expect(callHighlight('Hello World', null)).toBe('Hello World');
    });
  });

  describe('keyboard navigation - moveSelection', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = `
        <div id="results">
          <a class="global-search-item" href="/a">Item A</a>
          <a class="global-search-item" href="/b">Item B</a>
          <a class="global-search-item" href="/c">Item C</a>
        </div>
      `;

      ctx = {
        selectedIndex: -1,
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        get selectableItems() {
          return Array.from(this.resultsTarget.querySelectorAll('.global-search-item'));
        }
      };
    });

    it('selects first item when moving down from -1', () => {
      GlobalSearchController.prototype.moveSelection.call(ctx, 1);
      expect(ctx.selectedIndex).toBe(0);
      expect(ctx.selectableItems[0].classList.contains('selected')).toBe(true);
    });

    it('moves selection down', () => {
      ctx.selectedIndex = 0;
      ctx.selectableItems[0].classList.add('selected');

      GlobalSearchController.prototype.moveSelection.call(ctx, 1);
      expect(ctx.selectedIndex).toBe(1);
      expect(ctx.selectableItems[0].classList.contains('selected')).toBe(false);
      expect(ctx.selectableItems[1].classList.contains('selected')).toBe(true);
    });

    it('wraps around to first item when moving down past last', () => {
      ctx.selectedIndex = 2;
      ctx.selectableItems[2].classList.add('selected');

      GlobalSearchController.prototype.moveSelection.call(ctx, 1);
      expect(ctx.selectedIndex).toBe(0);
      expect(ctx.selectableItems[0].classList.contains('selected')).toBe(true);
      expect(ctx.selectableItems[2].classList.contains('selected')).toBe(false);
    });

    it('wraps around to last item when moving up past first', () => {
      ctx.selectedIndex = 0;
      ctx.selectableItems[0].classList.add('selected');

      GlobalSearchController.prototype.moveSelection.call(ctx, -1);
      expect(ctx.selectedIndex).toBe(2);
      expect(ctx.selectableItems[2].classList.contains('selected')).toBe(true);
      expect(ctx.selectableItems[0].classList.contains('selected')).toBe(false);
    });

    it('moves selection up', () => {
      ctx.selectedIndex = 2;
      ctx.selectableItems[2].classList.add('selected');

      GlobalSearchController.prototype.moveSelection.call(ctx, -1);
      expect(ctx.selectedIndex).toBe(1);
      expect(ctx.selectableItems[1].classList.contains('selected')).toBe(true);
      expect(ctx.selectableItems[2].classList.contains('selected')).toBe(false);
    });

    it('does nothing when there are no items', () => {
      ctx.resultsTarget.innerHTML = '';
      ctx.selectedIndex = -1;

      GlobalSearchController.prototype.moveSelection.call(ctx, 1);
      expect(ctx.selectedIndex).toBe(-1);
    });
  });

  describe('renderResults', () => {
    let ctx;

    function wrapKeyword(items) {
      return { keyword: items, semantic: [] };
    }

    beforeEach(() => {
      document.body.innerHTML = `
        <div id="results"></div>
        <div id="hint">Loading...</div>
      `;

      ctx = {
        element: { dataset: { coreSearchUrl: '/search', searchLabel: 'Search' } },
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 2,
        i18n: { noResults: 'No results' },
        currentScope: 'project',
        activeSearchType: null,
        titlesOnlyActive: false,
        escapeHtml: GlobalSearchController.prototype.escapeHtml,
        highlightMatch: GlobalSearchController.prototype.highlightMatch,
        renderGroup: GlobalSearchController.prototype.renderGroup,
        renderItem: GlobalSearchController.prototype.renderItem,
        renderCoreSearchLink: GlobalSearchController.prototype.renderCoreSearchLink,
        renderSearchTypeTabs: () => '',
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix,
        coreSearchScope: GlobalSearchController.prototype.coreSearchScope,
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint
      };
    });

    it('renders flat result list with type and project', () => {
      const data = [
        { title: 'Bug #42: Login broken', url: '/issues/42', type: 'Issues', project_name: 'Alpha' },
        { title: 'Wiki Page', url: '/wiki/page', type: 'Wiki' }
      ];

      GlobalSearchController.prototype.renderResults.call(ctx, wrapKeyword(data), 'test');

      const items = ctx.resultsTarget.querySelectorAll('.global-search-item');
      expect(items).toHaveLength(3); // 2 results + 1 core search link

      // First real result (after core search link)
      const firstResult = items[1];
      expect(firstResult.getAttribute('href')).toBe('/issues/42');
      expect(firstResult.querySelector('.global-search-item-title')).not.toBeNull();
      expect(firstResult.querySelector('.global-search-item-type').textContent).toBe('Issues');
      expect(firstResult.querySelector('.global-search-item-project').textContent).toBe('Alpha');

      // Second result has no project
      const secondResult = items[2];
      expect(secondResult.querySelector('.global-search-item-project')).toBeNull();
    });

    it('shows no results message when no groups', () => {
      GlobalSearchController.prototype.renderResults.call(ctx, {}, 'test');

      expect(ctx.resultsTarget.querySelector('.global-search-no-results')).not.toBeNull();
      expect(ctx.resultsTarget.querySelector('.global-search-core-link')).not.toBeNull();
      expect(ctx.selectedIndex).toBe(-1);
    });

    it('hides hint when results are present', () => {
      const data = {
        issues: {
          label: 'Issues',
          results: [{ title: 'Bug #1', url: '/issues/1' }]
        }
      };

      GlobalSearchController.prototype.renderResults.call(ctx, data, 'bug');

      expect(ctx.hintTarget.style.display).toBe('none');
    });

    it('resets selectedIndex when results are rendered', () => {
      const data = {
        issues: {
          label: 'Issues',
          results: [{ title: 'Bug #1', url: '/issues/1' }]
        }
      };

      ctx.selectedIndex = 5;
      GlobalSearchController.prototype.renderResults.call(ctx, data, 'bug');

      expect(ctx.selectedIndex).toBe(-1);
    });

    it('escapes HTML in titles', () => {
      const data = [
        { title: '<script>alert("xss")</script>', url: '/issues/1', type: 'Issues' }
      ];

      GlobalSearchController.prototype.renderResults.call(ctx, wrapKeyword(data), 'nomatch');

      const html = ctx.resultsTarget.innerHTML;
      expect(html).not.toContain('<script>');
      expect(html).toContain('&lt;script&gt;');
    });

    it('highlights query matches in titles', () => {
      const data = [{ title: 'Login broken', url: '/issues/1', type: 'Issues' }];

      GlobalSearchController.prototype.renderResults.call(ctx, wrapKeyword(data), 'Login');

      const items = ctx.resultsTarget.querySelectorAll('.global-search-item');
      const titleEl = items[1].querySelector('.global-search-item-title');
      expect(titleEl.innerHTML).toContain('<mark>Login</mark>');
    });

    it('does nothing when resultsTarget is missing', () => {
      ctx.hasResultsTarget = false;
      // Should not throw
      GlobalSearchController.prototype.renderResults.call(ctx, wrapKeyword([]), 'q');
    });

    it('renders items without project when project_name is absent', () => {
      const data = [{ title: 'Item', url: '/issues/1', type: 'Issues' }];

      GlobalSearchController.prototype.renderResults.call(ctx, wrapKeyword(data), 'test');

      const items = ctx.resultsTarget.querySelectorAll('.global-search-item');
      expect(items.length).toBeGreaterThan(0);
      // Item should not have project since none was provided
      expect(items[1].querySelector('.global-search-item-project')).toBeNull();
    });
  });

  describe('onGlobalKeydown', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = '<div id="overlay"></div>';

      ctx = {
        element: document.getElementById('overlay'),
        selectedIndex: -1,
        open: vi.fn(),
        close: vi.fn(),
        moveSelection: vi.fn(),
        openSelected: vi.fn()
      };
    });

    it('toggles open on Cmd+K when closed', () => {
      const event = { key: 'k', metaKey: true, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(ctx.open).toHaveBeenCalled();
    });

    it('toggles close on Cmd+K when open', () => {
      ctx.element.classList.add('active');
      const event = { key: 'k', metaKey: true, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.close).toHaveBeenCalled();
    });

    it('closes on Escape when active', () => {
      ctx.element.classList.add('active');
      const event = { key: 'Escape', metaKey: false, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.close).toHaveBeenCalled();
    });

    it('ignores Escape when not active', () => {
      const event = { key: 'Escape', metaKey: false, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.close).not.toHaveBeenCalled();
    });

    it('moves selection down on ArrowDown', () => {
      ctx.element.classList.add('active');
      const event = { key: 'ArrowDown', metaKey: false, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.moveSelection).toHaveBeenCalledWith(1);
    });

    it('moves selection up on ArrowUp', () => {
      ctx.element.classList.add('active');
      const event = { key: 'ArrowUp', metaKey: false, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.moveSelection).toHaveBeenCalledWith(-1);
    });

    it('opens selected on Enter', () => {
      ctx.element.classList.add('active');
      const event = { key: 'Enter', metaKey: false, ctrlKey: false, preventDefault: vi.fn() };
      GlobalSearchController.prototype.onGlobalKeydown.call(ctx, event);

      expect(ctx.openSelected).toHaveBeenCalled();
    });
  });

  describe('showHint / hideHint', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = '<div id="hint"></div>';

      ctx = {
        hasHintTarget: true,
        hintTarget: document.getElementById('hint')
      };
    });

    it('showHint sets text and shows element', () => {
      ctx.hintTarget.style.display = 'none';
      GlobalSearchController.prototype.showHint.call(ctx, 'Searching...');

      expect(ctx.hintTarget.textContent).toBe('Searching...');
      expect(ctx.hintTarget.style.display).toBe('');
    });

    it('hideHint hides element', () => {
      GlobalSearchController.prototype.hideHint.call(ctx);

      expect(ctx.hintTarget.style.display).toBe('none');
    });
  });

  describe('cancelPending', () => {
    it('clears debounce timer and aborts controller', () => {
      const abortSpy = vi.fn();
      const ctx = {
        debounceTimer: setTimeout(() => {}, 10000),
        abortController: { abort: abortSpy }
      };

      GlobalSearchController.prototype.cancelPending.call(ctx);

      expect(abortSpy).toHaveBeenCalled();
      expect(ctx.abortController).toBeNull();
    });

    it('handles null abortController gracefully', () => {
      const ctx = {
        debounceTimer: null,
        abortController: null
      };

      // Should not throw
      GlobalSearchController.prototype.cancelPending.call(ctx);
      expect(ctx.abortController).toBeNull();
    });
  });

  describe('openSelected', () => {
    it('navigates to selected item href', () => {
      document.body.innerHTML = `
        <div id="results">
          <a class="global-search-item" href="/issues/42">Item</a>
        </div>
      `;

      Object.defineProperty(window, 'location', {
        value: { href: '' },
        writable: true,
        configurable: true
      });

      const ctx = {
        selectedIndex: 0,
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        saveCurrentQuery: vi.fn(),
        get selectableItems() {
          return Array.from(this.resultsTarget.querySelectorAll('.global-search-item'));
        }
      };

      GlobalSearchController.prototype.openSelected.call(ctx);

      expect(ctx.saveCurrentQuery).toHaveBeenCalled();
      expect(window.location.href).toBe('/issues/42');
    });

    it('does nothing when no item is selected', () => {
      document.body.innerHTML = '<div id="results"></div>';

      const ctx = {
        selectedIndex: -1,
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        get selectableItems() {
          return Array.from(this.resultsTarget.querySelectorAll('.global-search-item'));
        }
      };

      // Should not throw
      GlobalSearchController.prototype.openSelected.call(ctx);
    });
  });

  describe('scope', () => {
    let ctx;
    let storage;

    beforeEach(() => {
      storage = {};
      const mockStorage = {
        getItem: key => storage[key] || null,
        setItem: (key, val) => { storage[key] = val; },
        removeItem: key => { delete storage[key]; }
      };
      Object.defineProperty(window, 'localStorage', { value: mockStorage, writable: true });
      document.body.innerHTML = `
        <div id="overlay" data-global-label="All Projects">
          <div id="badge" style="display:none"></div>
          <div id="panel" style="display:none">
            <input type="radio" name="global-search-scope" value="project" />
            <input type="radio" name="global-search-scope" value="global" />
            <input type="radio" name="global-search-scope" value="always_global" />
          </div>
        </div>
      `;

      ctx = {
        element: document.getElementById('overlay'),
        projectIdValue: 'test-project',
        projectNameValue: 'Test Project',
        hasInputTarget: false,
        hasScopePanelTarget: true,
        scopePanelTarget: document.getElementById('panel'),
        currentScope: null,
        initialData: null,
        persistentScopes: ['always_global', 'always_bookmarks'],
        updateScopeRadios: GlobalSearchController.prototype.updateScopeRadios,
        updatePlaceholder: vi.fn(),
        validateActiveSearchType: vi.fn(),
        loadInitialContent: vi.fn()
      };
    });

    it('initScope defaults to project when in a project', () => {
      GlobalSearchController.prototype.initScope.call(ctx);
      expect(ctx.currentScope).toBe('project');
    });

    it('initScope defaults to global when not in a project', () => {
      ctx.projectIdValue = '';
      GlobalSearchController.prototype.initScope.call(ctx);
      expect(ctx.currentScope).toBe('global');
    });

    it('initScope restores always_global from localStorage', () => {
      localStorage.setItem('global_search_scope', 'always_global');
      GlobalSearchController.prototype.initScope.call(ctx);
      expect(ctx.currentScope).toBe('always_global');
    });

    it('toggleScopePanel shows and hides panel', () => {
      GlobalSearchController.prototype.toggleScopePanel.call(ctx);
      expect(ctx.scopePanelTarget.style.display).toBe('');

      GlobalSearchController.prototype.toggleScopePanel.call(ctx);
      expect(ctx.scopePanelTarget.style.display).toBe('none');
    });

    it('effectiveProjectId returns null when global', () => {
      ctx.currentScope = 'global';
      expect(GlobalSearchController.prototype.effectiveProjectId.call(ctx)).toBeNull();
    });

    it('effectiveProjectId returns null when always_global', () => {
      ctx.currentScope = 'always_global';
      expect(GlobalSearchController.prototype.effectiveProjectId.call(ctx)).toBeNull();
    });

    it('effectiveProjectId returns projectIdValue when project scope', () => {
      ctx.currentScope = 'project';
      expect(GlobalSearchController.prototype.effectiveProjectId.call(ctx)).toBe('test-project');
    });

    it('updatePlaceholder shows scope in placeholder for global', () => {
      document.body.innerHTML = '<div id="el" data-scope-all="in all projects" data-search-label="Search"><input id="inp" /></div>';
      const pCtx = {
        element: document.getElementById('el'),
        hasInputTarget: true,
        inputTarget: document.getElementById('inp'),
        currentScope: 'global',
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix
      };
      GlobalSearchController.prototype.updatePlaceholder.call(pCtx);
      expect(pCtx.inputTarget.placeholder).toBe('Search in all projects...');
    });

    it('updatePlaceholder restores default placeholder for project scope', () => {
      document.body.innerHTML = '<div id="el" data-search-label="Search"><input id="inp" placeholder="Type to search..." /></div>';
      const pCtx = {
        element: document.getElementById('el'),
        hasInputTarget: true,
        inputTarget: document.getElementById('inp'),
        currentScope: 'project',
        defaultPlaceholder: 'Type to search...',
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix
      };
      GlobalSearchController.prototype.updatePlaceholder.call(pCtx);
      expect(pCtx.inputTarget.placeholder).toBe('Type to search...');
    });

    it('onScopeChange stores always_global in localStorage', () => {
      ctx.hasInputTarget = false;
      ctx.performSearch = vi.fn();
      GlobalSearchController.prototype.onScopeChange.call(ctx, { target: { value: 'always_global' } });
      expect(storage.global_search_scope).toBe('always_global');
    });

    it('onScopeChange removes localStorage for non-persistent scopes', () => {
      storage.global_search_scope = 'always_global';
      ctx.hasInputTarget = false;
      ctx.performSearch = vi.fn();
      GlobalSearchController.prototype.onScopeChange.call(ctx, { target: { value: 'project' } });
      expect(storage.global_search_scope).toBeUndefined();
    });
  });

  describe('search history', () => {
    let storage;

    beforeEach(() => {
      storage = {};
      const mockStorage = {
        getItem: key => storage[key] || null,
        setItem: (key, val) => { storage[key] = val; },
        removeItem: key => { delete storage[key]; }
      };
      Object.defineProperty(window, 'localStorage', { value: mockStorage, writable: true });
    });

    it('getSearchHistory returns empty array when no history', () => {
      const result = GlobalSearchController.prototype.getSearchHistory.call({});
      expect(result).toEqual([]);
    });

    it('getSearchHistory returns stored terms', () => {
      localStorage.setItem('global_search_history', JSON.stringify(['foo', 'bar']));
      const result = GlobalSearchController.prototype.getSearchHistory.call({});
      expect(result).toEqual(['foo', 'bar']);
    });

    it('getSearchHistory handles invalid JSON gracefully', () => {
      localStorage.setItem('global_search_history', 'not-json');
      const result = GlobalSearchController.prototype.getSearchHistory.call({});
      expect(result).toEqual([]);
    });

    it('saveCurrentQuery stores query when results exist', () => {
      const ctx = {
        hasResults: true,
        hasInputTarget: true,
        inputTarget: { value: '  redmine api  ' },
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      const saved = JSON.parse(localStorage.getItem('global_search_history'));
      expect(saved).toEqual(['redmine api']);
    });

    it('saveCurrentQuery does not store when no results', () => {
      const ctx = {
        hasResults: false,
        hasInputTarget: true,
        inputTarget: { value: 'test' }
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      expect(localStorage.getItem('global_search_history')).toBeNull();
    });

    it('saveCurrentQuery does not store short queries', () => {
      const ctx = {
        hasResults: true,
        hasInputTarget: true,
        inputTarget: { value: 'a' },
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      expect(localStorage.getItem('global_search_history')).toBeNull();
    });

    it('saveCurrentQuery deduplicates case-insensitively', () => {
      localStorage.setItem('global_search_history', JSON.stringify(['Redmine API', 'other']));

      const ctx = {
        hasResults: true,
        hasInputTarget: true,
        inputTarget: { value: 'redmine api' },
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      const saved = JSON.parse(localStorage.getItem('global_search_history'));
      expect(saved).toEqual(['redmine api', 'other']);
    });

    it('saveCurrentQuery prepends new term', () => {
      localStorage.setItem('global_search_history', JSON.stringify(['old term']));

      const ctx = {
        hasResults: true,
        hasInputTarget: true,
        inputTarget: { value: 'new term' },
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      const saved = JSON.parse(localStorage.getItem('global_search_history'));
      expect(saved[0]).toBe('new term');
      expect(saved[1]).toBe('old term');
    });

    it('saveCurrentQuery limits to MAX_HISTORY_ENTRIES', () => {
      const existing = Array.from({ length: 20 }, (_, i) => `term ${i}`);
      localStorage.setItem('global_search_history', JSON.stringify(existing));

      const ctx = {
        hasResults: true,
        hasInputTarget: true,
        inputTarget: { value: 'newest' },
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory
      };

      GlobalSearchController.prototype.saveCurrentQuery.call(ctx);

      const saved = JSON.parse(localStorage.getItem('global_search_history'));
      expect(saved.length).toBe(15);
      expect(saved[0]).toBe('newest');
    });

    it('clearHistory removes localStorage and DOM section', () => {
      localStorage.setItem('global_search_history', JSON.stringify(['test']));
      document.body.innerHTML = `
        <div id="results">
          <div class="global-search-history-section">history</div>
          <div>other</div>
        </div>
      `;

      const ctx = {
        resultsTarget: document.getElementById('results')
      };

      const event = { preventDefault: vi.fn() };
      GlobalSearchController.prototype.clearHistory.call(ctx, event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(localStorage.getItem('global_search_history')).toBeNull();
      expect(ctx.resultsTarget.querySelector('.global-search-history-section')).toBeNull();
    });

    it('renderHistorySection renders terms with data-search-term', () => {
      const ctx = {
        i18n: { recentSearches: 'Recently searched', clearAll: 'Clear all' },
        escapeHtml: GlobalSearchController.prototype.escapeHtml
      };

      const html = GlobalSearchController.prototype.renderHistorySection.call(ctx, ['foo', 'bar']);

      expect(html).toContain('data-search-term="foo"');
      expect(html).toContain('data-search-term="bar"');
      expect(html).toContain('Recently searched');
      expect(html).toContain('Clear all');
      expect(html).toContain('global-search-history-section');
    });

    it('renderInitialContent shows history and projects', () => {
      document.body.innerHTML = `
        <div id="results"></div>
        <div id="hint"></div>
      `;

      localStorage.setItem('global_search_history', JSON.stringify(['test query']));

      const ctx = {
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 2,
        i18n: {
          hint: 'Type to search...',
          recentSearches: 'Recently searched',
          recentProjects: 'Recently used projects',
          clearAll: 'Clear all'
        },
        escapeHtml: GlobalSearchController.prototype.escapeHtml,
        highlightMatch: GlobalSearchController.prototype.highlightMatch,
        renderItem: GlobalSearchController.prototype.renderItem,
        renderHistorySection: GlobalSearchController.prototype.renderHistorySection,
        getSearchHistory: GlobalSearchController.prototype.getSearchHistory,
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint
      };

      const data = {
        keyword: [{ title: 'My Project', url: '/projects/my', type: 'Project' }]
      };

      GlobalSearchController.prototype.renderInitialContent.call(ctx, data);

      const html = ctx.resultsTarget.innerHTML;
      expect(html).toContain('global-search-history-section');
      expect(html).toContain('test query');
      expect(html).toContain('Recently used projects');
      expect(html).toContain('My Project');
    });

    it('renderInitialContent shows hint when no history and no projects', () => {
      document.body.innerHTML = `
        <div id="results"></div>
        <div id="hint" style="display:none"></div>
      `;

      const ctx = {
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 0,
        i18n: { hint: 'Type to search...', recentSearches: 'R', recentProjects: 'P', clearAll: 'C' },
        getSearchHistory: () => [],
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint
      };

      GlobalSearchController.prototype.renderInitialContent.call(ctx, { keyword: [] });

      expect(ctx.hintTarget.style.display).toBe('');
      expect(ctx.hintTarget.textContent).toBe('Type to search...');
    });

    it('onHistoryTermClick fills input and performs search', () => {
      document.body.innerHTML = `
        <div id="results">
          <a class="global-search-item" data-search-term="redmine api">
            <span class="global-search-item-title">redmine api</span>
          </a>
        </div>
      `;

      const ctx = {
        hasInputTarget: true,
        inputTarget: { value: '' },
        performSearch: vi.fn(),
        toggleClearButton: vi.fn()
      };

      const item = document.querySelector('[data-search-term]');
      const event = {
        preventDefault: vi.fn(),
        target: item.querySelector('.global-search-item-title')
      };

      GlobalSearchController.prototype.onHistoryTermClick.call(ctx, event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(ctx.inputTarget.value).toBe('redmine api');
      expect(ctx.performSearch).toHaveBeenCalledWith('redmine api');
    });
  });

  describe('open with query', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = `
        <div id="overlay">
          <input id="search-input" type="text" />
        </div>
      `;

      ctx = {
        element: document.getElementById('overlay'),
        hasInputTarget: true,
        inputTarget: document.getElementById('search-input'),
        selectedIndex: 5,
        lastQuery: 'old',
        hasResults: false,
        loadInitialContent: vi.fn(),
        performSearch: vi.fn(),
        toggleClearButton: vi.fn()
      };
    });

    it('open without query loads initial content', () => {
      GlobalSearchController.prototype.open.call(ctx);
      expect(ctx.inputTarget.value).toBe('');
      expect(ctx.loadInitialContent).toHaveBeenCalled();
      expect(ctx.performSearch).not.toHaveBeenCalled();
    });

    it('open with query performs search immediately', () => {
      GlobalSearchController.prototype.open.call(ctx, 'test query');
      expect(ctx.inputTarget.value).toBe('test query');
      expect(ctx.performSearch).toHaveBeenCalledWith('test query');
      expect(ctx.loadInitialContent).not.toHaveBeenCalled();
    });

    it('open with short query loads initial content', () => {
      GlobalSearchController.prototype.open.call(ctx, 'a');
      expect(ctx.inputTarget.value).toBe('a');
      expect(ctx.loadInitialContent).toHaveBeenCalled();
      expect(ctx.performSearch).not.toHaveBeenCalled();
    });
  });

  describe('search type tabs', () => {
    it('getSearchTypes returns global types by default', () => {
      const ctx = {
        currentScope: 'global',
        element: { dataset: { searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }]) } }
      };
      const result = GlobalSearchController.prototype.getSearchTypes.call(ctx);
      expect(result).toEqual([{ id: 'issues', label: 'Issues' }]);
    });

    it('getSearchTypes returns project types when scope is project', () => {
      const ctx = {
        currentScope: 'project',
        element: {
          dataset: {
            searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }, { id: 'projects', label: 'Projects' }]),
            searchTypesProject: JSON.stringify([{ id: 'issues', label: 'Issues' }])
          }
        }
      };
      const result = GlobalSearchController.prototype.getSearchTypes.call(ctx);
      expect(result).toEqual([{ id: 'issues', label: 'Issues' }]);
    });

    it('getSearchTypes returns global types for bookmarks scope', () => {
      const ctx = {
        currentScope: 'bookmarks',
        element: {
          dataset: {
            searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }, { id: 'projects', label: 'Projects' }]),
            searchTypesProject: JSON.stringify([{ id: 'issues', label: 'Issues' }])
          }
        }
      };
      const result = GlobalSearchController.prototype.getSearchTypes.call(ctx);
      expect(result).toHaveLength(2);
    });

    it('getSearchTypes returns empty array for invalid JSON', () => {
      const ctx = {
        currentScope: 'global',
        element: { dataset: { searchTypes: 'invalid' } }
      };
      const result = GlobalSearchController.prototype.getSearchTypes.call(ctx);
      expect(result).toEqual([]);
    });

    it('renderSearchTypeTabs generates HTML with all tab and type tabs', () => {
      const ctx = {
        currentScope: 'global',
        activeSearchType: null,
        element: {
          dataset: {
            tabAll: 'All',
            searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }, { id: 'wiki_pages', label: 'Wiki' }])
          }
        },
        getSearchTypes: GlobalSearchController.prototype.getSearchTypes,
        escapeHtml: GlobalSearchController.prototype.escapeHtml
      };
      const html = GlobalSearchController.prototype.renderSearchTypeTabs.call(ctx);
      expect(html).toContain('All');
      expect(html).toContain('Issues');
      expect(html).toContain('Wiki');
      expect(html).toContain('data-type-id=""');
      expect(html).toContain('data-type-id="issues"');
      expect(html).toContain('data-type-id="wiki_pages"');
    });

    it('renderSearchTypeTabs marks active type', () => {
      const ctx = {
        currentScope: 'global',
        activeSearchType: 'issues',
        element: {
          dataset: {
            tabAll: 'All',
            searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }])
          }
        },
        getSearchTypes: GlobalSearchController.prototype.getSearchTypes,
        escapeHtml: GlobalSearchController.prototype.escapeHtml
      };
      const html = GlobalSearchController.prototype.renderSearchTypeTabs.call(ctx);
      expect(html).toContain('data-type-id="issues"');
      expect(html).toMatch(/data-type-id="issues"[^>]*href="#"[^>]*>/);
    });

    it('renderSearchTypeTabs returns empty string when no types', () => {
      const ctx = {
        currentScope: 'global',
        activeSearchType: null,
        element: { dataset: { searchTypes: '[]' } },
        getSearchTypes: GlobalSearchController.prototype.getSearchTypes
      };
      const html = GlobalSearchController.prototype.renderSearchTypeTabs.call(ctx);
      expect(html).toBe('');
    });

    it('onSearchTypeClick sets active type and triggers search', () => {
      document.body.innerHTML = '<div id="tabs"><a class="global-search-tab" data-type-id="issues">Issues</a></div>';
      const ctx = {
        activeSearchType: null,
        hasInputTarget: true,
        inputTarget: { value: 'test query' },

        updateSearchTypeTabs: vi.fn(),
        performSearch: vi.fn()
      };
      const tab = document.querySelector('[data-type-id]');
      const event = { preventDefault: vi.fn(), target: tab };
      GlobalSearchController.prototype.onSearchTypeClick.call(ctx, event);
      expect(ctx.activeSearchType).toBe('issues');
      expect(ctx.performSearch).toHaveBeenCalledWith('test query');
    });

    it('onSearchTypeClick resets to all when clicking all tab', () => {
      document.body.innerHTML = '<div id="tabs"><a class="global-search-tab" data-type-id="">All</a></div>';
      const ctx = {
        activeSearchType: 'issues',
        hasInputTarget: true,
        inputTarget: { value: 'test' },

        updateSearchTypeTabs: vi.fn(),
        performSearch: vi.fn()
      };
      const tab = document.querySelector('[data-type-id]');
      const event = { preventDefault: vi.fn(), target: tab };
      GlobalSearchController.prototype.onSearchTypeClick.call(ctx, event);
      expect(ctx.activeSearchType).toBeNull();
    });

    it('validateActiveSearchType resets type if not in current list', () => {
      const ctx = {
        activeSearchType: 'contacts',
        currentScope: 'project',
        element: {
          dataset: {
            searchTypesProject: JSON.stringify([{ id: 'issues', label: 'Issues' }])
          }
        },
        getSearchTypes: GlobalSearchController.prototype.getSearchTypes
      };
      GlobalSearchController.prototype.validateActiveSearchType.call(ctx);
      expect(ctx.activeSearchType).toBeNull();
    });

    it('validateActiveSearchType keeps type if still in list', () => {
      const ctx = {
        activeSearchType: 'issues',
        currentScope: 'global',
        element: {
          dataset: {
            searchTypes: JSON.stringify([{ id: 'issues', label: 'Issues' }])
          }
        },
        getSearchTypes: GlobalSearchController.prototype.getSearchTypes
      };
      GlobalSearchController.prototype.validateActiveSearchType.call(ctx);
      expect(ctx.activeSearchType).toBe('issues');
    });
  });

  describe('clear input', () => {
    it('clearInput clears value, hides clear button and loads initial content', () => {
      document.body.innerHTML = '<div><input id="inp" value="test" /><div id="res"></div></div>';
      const ctx = {
        hasInputTarget: true,
        inputTarget: document.getElementById('inp'),
        hasResultsTarget: true,
        resultsTarget: document.getElementById('res'),
        hasClearButtonTarget: true,
        clearButtonTarget: { style: { display: '' } },
        toggleClearButton: GlobalSearchController.prototype.toggleClearButton,
        loadInitialContent: vi.fn()
      };
      GlobalSearchController.prototype.clearInput.call(ctx);
      expect(ctx.inputTarget.value).toBe('');
      expect(ctx.clearButtonTarget.style.display).toBe('none');
      expect(ctx.loadInitialContent).toHaveBeenCalled();
    });
  });

  describe('semantic results with type filter', () => {
    it('hides semantic results when a search type is active', () => {
      document.body.innerHTML = '<div id="results"></div><div id="hint"></div>';
      const ctx = {
        element: { dataset: { coreSearchUrl: '/search', searchLabel: 'Search' } },
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 0,
        activeSearchType: 'issues',
        titlesOnlyActive: false,
        i18n: { noResults: 'No results' },
        currentScope: 'global',
        escapeHtml: GlobalSearchController.prototype.escapeHtml,
        highlightMatch: GlobalSearchController.prototype.highlightMatch,
        renderItem: GlobalSearchController.prototype.renderItem,
        renderCoreSearchLink: GlobalSearchController.prototype.renderCoreSearchLink,
        renderSearchTypeTabs: () => '',
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix,
        coreSearchScope: GlobalSearchController.prototype.coreSearchScope,
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint
      };
      const data = {
        keyword: [{ title: 'Issue #1', url: '/issues/1', type: 'Issues' }],
        semantic: { label: 'Semantic', results: [{ title: 'Related', url: '/issues/2', type: 'Issues' }] }
      };
      GlobalSearchController.prototype.renderResults.call(ctx, data, 'test');
      expect(ctx.resultsTarget.innerHTML).not.toContain('Semantic');
    });

    it('shows semantic results when no search type is active', () => {
      document.body.innerHTML = '<div id="results"></div><div id="hint"></div>';
      const ctx = {
        element: { dataset: { coreSearchUrl: '/search', searchLabel: 'Search', semanticIcon: '' } },
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        selectedIndex: 0,
        activeSearchType: null,
        titlesOnlyActive: false,
        i18n: { noResults: 'No results' },
        currentScope: 'global',
        escapeHtml: GlobalSearchController.prototype.escapeHtml,
        highlightMatch: GlobalSearchController.prototype.highlightMatch,
        renderItem: GlobalSearchController.prototype.renderItem,
        renderCoreSearchLink: GlobalSearchController.prototype.renderCoreSearchLink,
        renderSearchTypeTabs: () => '',
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix,
        coreSearchScope: GlobalSearchController.prototype.coreSearchScope,
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint
      };
      const data = {
        keyword: [{ title: 'Issue #1', url: '/issues/1', type: 'Issues' }],
        semantic: { label: 'Semantic', results: [{ title: 'Related', url: '/issues/2', type: 'Issues' }] }
      };
      GlobalSearchController.prototype.renderResults.call(ctx, data, 'test');
      expect(ctx.resultsTarget.innerHTML).toContain('Semantic');
    });
  });

  describe('scope mapping', () => {
    it('effectiveSearchScope returns bookmarks for bookmark scopes', () => {
      const ctx = { currentScope: 'bookmarks' };
      expect(GlobalSearchController.prototype.effectiveSearchScope.call(ctx)).toBe('bookmarks');

      ctx.currentScope = 'always_bookmarks';
      expect(GlobalSearchController.prototype.effectiveSearchScope.call(ctx)).toBe('bookmarks');
    });

    it('effectiveSearchScope returns null for global and project scopes', () => {
      const ctx = { currentScope: 'global' };
      expect(GlobalSearchController.prototype.effectiveSearchScope.call(ctx)).toBeNull();

      ctx.currentScope = 'project';
      expect(GlobalSearchController.prototype.effectiveSearchScope.call(ctx)).toBeNull();
    });

    it('coreSearchScope maps to core search scope values', () => {
      const ctx = { currentScope: 'global' };
      expect(GlobalSearchController.prototype.coreSearchScope.call(ctx)).toBe('all');

      ctx.currentScope = 'always_global';
      expect(GlobalSearchController.prototype.coreSearchScope.call(ctx)).toBe('all');

      ctx.currentScope = 'bookmarks';
      expect(GlobalSearchController.prototype.coreSearchScope.call(ctx)).toBe('bookmarks');

      ctx.currentScope = 'project';
      expect(GlobalSearchController.prototype.coreSearchScope.call(ctx)).toBeNull();
    });
  });

  describe('renderCoreSearchLink', () => {
    let ctx;

    beforeEach(() => {
      ctx = {
        element: { dataset: { coreSearchUrl: '/search', searchLabel: 'Search', titlesOnlyPrefix: 'in titles' } },
        currentScope: 'global',
        activeSearchType: null,
        titlesOnlyActive: false,
        escapeHtml: GlobalSearchController.prototype.escapeHtml,
        scopeSuffix: GlobalSearchController.prototype.scopeSuffix,
        coreSearchScope: GlobalSearchController.prototype.coreSearchScope
      };
    });

    it('builds URL with query parameter', () => {
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).toContain('q=test');
      expect(html).toContain('href="/search?');
    });

    it('includes scope=all for global scope', () => {
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).toContain('scope=all');
    });

    it('includes titles_only when active', () => {
      ctx.titlesOnlyActive = true;
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).toContain('titles_only=1');
    });

    it('includes type filter when active', () => {
      ctx.activeSearchType = 'wiki_pages';
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).toContain('wiki_pages=1');
    });

    it('does not include scope for project scope', () => {
      ctx.currentScope = 'project';
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).not.toContain('scope=');
    });

    it('returns empty string when no coreSearchUrl', () => {
      ctx.element = { dataset: {} };
      const html = GlobalSearchController.prototype.renderCoreSearchLink.call(ctx, 'test');
      expect(html).toBe('');
    });
  });

  describe('onInput behavior', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = '<div><input id="inp" /><div id="res"></div></div>';
      ctx = {
        hasInputTarget: true,
        inputTarget: document.getElementById('inp'),
        lastQuery: '',
        debounceTimer: null,
        hasClearButtonTarget: true,
        clearButtonTarget: { style: { display: 'none' } },
        toggleClearButton: GlobalSearchController.prototype.toggleClearButton,
        loadInitialContent: vi.fn(),
        performSearch: vi.fn()
      };
    });

    it('calls loadInitialContent for short queries', () => {
      ctx.inputTarget.value = 'a';
      GlobalSearchController.prototype.onInput.call(ctx);
      expect(ctx.loadInitialContent).toHaveBeenCalled();
      expect(ctx.lastQuery).toBe('a');
    });

    it('shows clear button when input has text', () => {
      ctx.inputTarget.value = 'test';
      GlobalSearchController.prototype.onInput.call(ctx);
      expect(ctx.clearButtonTarget.style.display).toBe('');
    });

    it('hides clear button when input is empty', () => {
      ctx.clearButtonTarget.style.display = '';
      ctx.inputTarget.value = '';
      GlobalSearchController.prototype.onInput.call(ctx);
      expect(ctx.clearButtonTarget.style.display).toBe('none');
    });

    it('does not search when query equals lastQuery', () => {
      ctx.inputTarget.value = 'test';
      ctx.lastQuery = 'test';
      GlobalSearchController.prototype.onInput.call(ctx);
      expect(ctx.performSearch).not.toHaveBeenCalled();
      expect(ctx.loadInitialContent).not.toHaveBeenCalled();
    });
  });

  describe('performSearch error handling', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = `
        <div id="overlay" data-global-search-url-value="/global_search/search">
          <input id="search-input" type="text" />
          <div id="results"></div>
          <div id="hint"></div>
        </div>
      `;

      ctx = {
        element: document.getElementById('overlay'),
        urlValue: '/global_search/search',
        hasInputTarget: true,
        inputTarget: document.getElementById('search-input'),
        hasResultsTarget: true,
        resultsTarget: document.getElementById('results'),
        hasHintTarget: true,
        hintTarget: document.getElementById('hint'),
        lastQuery: '',
        abortController: null,
        activeSearchType: null,
        titlesOnlyActive: false,
        currentScope: 'global',
        i18n: { noResults: 'No results', loading: 'Loading...' },
        cancelPending: GlobalSearchController.prototype.cancelPending,
        setLoading: GlobalSearchController.prototype.setLoading,
        showHint: GlobalSearchController.prototype.showHint,
        hideHint: GlobalSearchController.prototype.hideHint,
        renderResults: vi.fn(),
        effectiveProjectId: () => null,
        effectiveSearchScope: () => null,
        debounceTimer: null
      };
    });

    it('clears loading state when response is not ok', async () => {
      vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }));
      vi.stubGlobal('AdditionalsHelpers', { csrfToken: () => 'token' });

      await GlobalSearchController.prototype.performSearch.call(ctx, 'test query');

      expect(ctx.inputTarget.classList.contains('ajax-loading')).toBe(false);
      expect(ctx.hintTarget.textContent).toBe('No results');

      vi.unstubAllGlobals();
    });

    it('clears loading state on network error', async () => {
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));
      vi.stubGlobal('AdditionalsHelpers', { csrfToken: () => 'token' });

      await GlobalSearchController.prototype.performSearch.call(ctx, 'test query');

      expect(ctx.inputTarget.classList.contains('ajax-loading')).toBe(false);
      expect(ctx.hintTarget.textContent).toBe('No results');

      vi.unstubAllGlobals();
    });

    it('does not show error hint on abort', async () => {
      const abortError = new DOMException('The operation was aborted.', 'AbortError');
      vi.stubGlobal('fetch', vi.fn().mockRejectedValue(abortError));
      vi.stubGlobal('AdditionalsHelpers', { csrfToken: () => 'token' });

      await GlobalSearchController.prototype.performSearch.call(ctx, 'test query');

      expect(ctx.inputTarget.classList.contains('ajax-loading')).toBe(false);
      expect(ctx.hintTarget.textContent).not.toBe('No results');

      vi.unstubAllGlobals();
    });
  });

  describe('titles only', () => {
    it('onTitlesOnlyChange toggles flag and hides panel', () => {
      const ctx = {
        titlesOnlyActive: false,
        hasScopePanelTarget: true,
        scopePanelTarget: { style: { display: '' } },
        hasInputTarget: true,
        inputTarget: { value: 'test', trim: () => 'test' },
        updatePlaceholder: vi.fn(),
        performSearch: vi.fn()
      };
      // Fix: inputTarget.value.trim()
      ctx.inputTarget = { value: '  test  ' };

      GlobalSearchController.prototype.onTitlesOnlyChange.call(ctx, { target: { checked: true } });
      expect(ctx.titlesOnlyActive).toBe(true);
      expect(ctx.scopePanelTarget.style.display).toBe('none');
      expect(ctx.updatePlaceholder).toHaveBeenCalled();
      expect(ctx.performSearch).toHaveBeenCalledWith('test');
    });

    it('onTitlesOnlyChange does not search with short query', () => {
      const ctx = {
        titlesOnlyActive: false,
        hasScopePanelTarget: true,
        scopePanelTarget: { style: { display: '' } },
        hasInputTarget: true,
        inputTarget: { value: 'a' },
        updatePlaceholder: vi.fn(),
        performSearch: vi.fn()
      };

      GlobalSearchController.prototype.onTitlesOnlyChange.call(ctx, { target: { checked: true } });
      expect(ctx.titlesOnlyActive).toBe(true);
      expect(ctx.performSearch).not.toHaveBeenCalled();
    });

    it('initTitlesOnly sets checkbox state', () => {
      const checkbox = { checked: false };
      const ctx = {
        hasTitlesOnlyTarget: true,
        titlesOnlyTarget: checkbox,
        titlesOnlyActive: true
      };
      GlobalSearchController.prototype.initTitlesOnly.call(ctx);
      expect(checkbox.checked).toBe(true);
    });
  });
});
