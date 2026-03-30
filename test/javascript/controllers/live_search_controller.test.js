import { describe, it, expect, beforeEach, vi } from 'vitest';
import LiveSearchController from '../../../assets/javascripts/controllers/live_search_controller.js';

describe('LiveSearchController', () => {
  describe('static declarations', () => {
    it('declares expected values', () => {
      expect(LiveSearchController.values.url).toBe(String);
      expect(LiveSearchController.values.target).toBe(String);
    });
  });

  describe('connect', () => {
    it('adds livesearch class and stores initial value', () => {
      document.body.innerHTML = '<input id="search" value="initial" />';
      const ctx = {
        element: document.getElementById('search'),
        debounceTimer: null
      };

      LiveSearchController.prototype.connect.call(ctx);

      expect(ctx.element.classList.contains('livesearch')).toBe(true);
      expect(ctx.lastValue).toBe('initial');
    });
  });

  describe('onInput', () => {
    it('debounces and calls performSearch', () => {
      vi.useFakeTimers();
      const ctx = {
        debounceTimer: null,
        performSearch: vi.fn()
      };

      LiveSearchController.prototype.onInput.call(ctx);

      expect(ctx.performSearch).not.toHaveBeenCalled();

      vi.advanceTimersByTime(400);

      expect(ctx.performSearch).toHaveBeenCalled();
      vi.useRealTimers();
    });

    it('clears previous timer on rapid input', () => {
      vi.useFakeTimers();
      const ctx = {
        debounceTimer: null,
        performSearch: vi.fn()
      };

      LiveSearchController.prototype.onInput.call(ctx);
      LiveSearchController.prototype.onInput.call(ctx);
      LiveSearchController.prototype.onInput.call(ctx);

      vi.advanceTimersByTime(400);

      expect(ctx.performSearch).toHaveBeenCalledTimes(1);
      vi.useRealTimers();
    });
  });

  describe('performSearch', () => {
    it('does nothing when value has not changed', () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch');
      const ctx = {
        element: { value: 'test', classList: { add: vi.fn(), remove: vi.fn() } },
        lastValue: 'test',
        hasUrlValue: false,
        hasTargetValue: false
      };

      LiveSearchController.prototype.performSearch.call(ctx);

      expect(fetchSpy).not.toHaveBeenCalled();
      fetchSpy.mockRestore();
    });

    it('fetches with URL value when provided', async () => {
      document.body.innerHTML = '<div id="results"></div>';
      const mockResponse = { text: vi.fn().mockResolvedValue('<p>results</p>') };
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValue(mockResponse);

      const ctx = {
        element: { value: 'new query', classList: { add: vi.fn(), remove: vi.fn() } },
        lastValue: '',
        hasUrlValue: true,
        urlValue: '/search',
        hasTargetValue: true,
        targetValue: 'results'
      };

      LiveSearchController.prototype.performSearch.call(ctx);

      expect(fetchSpy).toHaveBeenCalled();
      expect(ctx.element.classList.add).toHaveBeenCalledWith('ajax-loading');

      // Wait for promise chain
      await new Promise(resolve => { setTimeout(resolve, 0); });
      await new Promise(resolve => { setTimeout(resolve, 0); });

      expect(document.getElementById('results').innerHTML).toBe('<p>results</p>');
      fetchSpy.mockRestore();
    });

    it('uses form action when no URL value', async () => {
      document.body.innerHTML = `
        <form id="query_form" action="/issues">
          <input name="q" value="test" />
          <select name="c[]"><option value="col1">Col1</option></select>
        </form>
        <div id="query-result-list"></div>
      `;

      const mockResponse = { text: vi.fn().mockResolvedValue('<p>filtered</p>') };
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValue(mockResponse);

      const ctx = {
        element: { value: 'new', classList: { add: vi.fn(), remove: vi.fn() } },
        lastValue: '',
        hasUrlValue: false,
        hasTargetValue: false,
        selectAllColumns: LiveSearchController.prototype.selectAllColumns
      };

      LiveSearchController.prototype.performSearch.call(ctx);

      expect(fetchSpy).toHaveBeenCalled();

      const fetchUrl = fetchSpy.mock.calls[0][0];

      expect(fetchUrl).toContain('/issues');
      fetchSpy.mockRestore();
    });
  });

  describe('selectAllColumns', () => {
    it('selects and deselects all options', () => {
      document.body.innerHTML = `
        <form id="form">
          <select name="c[]" multiple>
            <option value="a">A</option>
            <option value="b">B</option>
          </select>
        </form>
      `;

      const form = document.getElementById('form');
      const options = form.querySelectorAll('[name="c[]"] option');

      LiveSearchController.prototype.selectAllColumns(form, true);

      expect(options[0].selected).toBe(true);
      expect(options[1].selected).toBe(true);

      LiveSearchController.prototype.selectAllColumns(form, false);

      expect(options[0].selected).toBe(false);
      expect(options[1].selected).toBe(false);
    });
  });
});
