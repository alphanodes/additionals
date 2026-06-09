import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import RenderAsyncController from '../../../assets/javascripts/controllers/render_async_controller.js';

describe('RenderAsyncController', () => {
  describe('static declarations', () => {
    it('declares expected values', () => {
      expect(RenderAsyncController.values.url).toBe(String);
      expect(RenderAsyncController.values.interval).toEqual({ type: Number, default: 0 });
      expect(RenderAsyncController.values.toggleSelector).toEqual({ type: String, default: '' });
      expect(RenderAsyncController.values.toggleEvent).toEqual({ type: String, default: 'click' });
      expect(RenderAsyncController.values.errorMessage).toEqual({ type: String, default: '' });
    });
  });

  describe('handleVisibilityChange', () => {
    let ctx;

    beforeEach(() => {
      ctx = {
        intervalId: 42,
        load: vi.fn(),
        stopPolling() {
          this.intervalId = null;
        }
      };
    });

    afterEach(() => {
      Object.defineProperty(document, 'hidden', { value: false, configurable: true });
    });

    it('stops polling when tab becomes hidden', () => {
      Object.defineProperty(document, 'hidden', { value: true, configurable: true });

      RenderAsyncController.prototype.handleVisibilityChange.call(ctx);

      expect(ctx.intervalId).toBeNull();
      expect(ctx.load).not.toHaveBeenCalled();
    });

    it('triggers immediate load when tab becomes visible and polling was paused', () => {
      Object.defineProperty(document, 'hidden', { value: false, configurable: true });
      ctx.intervalId = null;

      RenderAsyncController.prototype.handleVisibilityChange.call(ctx);

      expect(ctx.load).toHaveBeenCalledOnce();
    });

    it('does not reload when tab is visible and polling is already active', () => {
      Object.defineProperty(document, 'hidden', { value: false, configurable: true });
      ctx.intervalId = 99;

      RenderAsyncController.prototype.handleVisibilityChange.call(ctx);

      expect(ctx.load).not.toHaveBeenCalled();
      expect(ctx.intervalId).toBe(99);
    });
  });

  describe('handleToggle', () => {
    let ctx;

    beforeEach(() => {
      ctx = {
        intervalId: null,
        load: vi.fn(),
        stopPolling: vi.fn()
      };
    });

    it('triggers load when nothing is polling yet', () => {
      RenderAsyncController.prototype.handleToggle.call(ctx);

      expect(ctx.load).toHaveBeenCalledOnce();
      expect(ctx.stopPolling).not.toHaveBeenCalled();
    });

    it('stops polling when already active', () => {
      ctx.intervalId = 7;

      RenderAsyncController.prototype.handleToggle.call(ctx);

      expect(ctx.stopPolling).toHaveBeenCalledOnce();
      expect(ctx.load).not.toHaveBeenCalled();
    });
  });

  describe('stopPolling', () => {
    let ctx;
    let clearIntervalSpy;

    beforeEach(() => {
      clearIntervalSpy = vi.spyOn(globalThis, 'clearInterval');
      ctx = { intervalId: 123 };
    });

    afterEach(() => {
      clearIntervalSpy.mockRestore();
    });

    it('clears the interval and resets the id', () => {
      RenderAsyncController.prototype.stopPolling.call(ctx);

      expect(clearIntervalSpy).toHaveBeenCalledWith(123);
      expect(ctx.intervalId).toBeNull();
    });

    it('is a no-op when no interval is set', () => {
      ctx.intervalId = null;

      RenderAsyncController.prototype.stopPolling.call(ctx);

      expect(clearIntervalSpy).not.toHaveBeenCalled();
    });
  });

  describe('parseHTML', () => {
    it('re-creates script elements so the browser executes them', () => {
      const html = '<div>before</div><script>window.__rerunScriptFlag = "ran";</script>';

      const fragment = RenderAsyncController.prototype.parseHTML.call({}, html);
      const scripts = fragment.querySelectorAll('script');

      expect(scripts).toHaveLength(1);
      // After parseHTML, the script is a freshly-created element (not the one that
      // came out of template.innerHTML). The original was inert; this clone is live.
      expect(scripts[0].textContent).toBe('window.__rerunScriptFlag = "ran";');
    });

    it('copies script attributes onto the re-created node', () => {
      const html = '<script type="application/javascript" data-x="y">/* noop */</script>';

      const fragment = RenderAsyncController.prototype.parseHTML.call({}, html);
      const script = fragment.querySelector('script');

      expect(script.getAttribute('type')).toBe('application/javascript');
      expect(script.dataset.x).toBe('y');
    });

    it('passes through non-script content unchanged', () => {
      const html = '<p>plain</p><span class="x">stuff</span>';

      const fragment = RenderAsyncController.prototype.parseHTML.call({}, html);

      expect(fragment.querySelector('p').textContent).toBe('plain');
      expect(fragment.querySelector('span.x').textContent).toBe('stuff');
    });

    it('handles table-row fragments without wrapping them in a div', () => {
      // The <template> insertion mode allows <tr> outside a <table>.
      // The taskboard infinite-load uses html_element_name: 'tr', so this matters.
      const html = '<tr><td>cell</td></tr>';

      const fragment = RenderAsyncController.prototype.parseHTML.call({}, html);
      const tr = fragment.querySelector('tr');

      expect(tr).not.toBeNull();
      expect(tr.querySelector('td').textContent).toBe('cell');
    });
  });

  describe('csrfToken', () => {
    afterEach(() => {
      document.head.innerHTML = '';
    });

    it('returns the content of the csrf-token meta tag', () => {
      document.head.innerHTML = '<meta name="csrf-token" content="abc123">';

      const token = RenderAsyncController.prototype.csrfToken.call({});

      expect(token).toBe('abc123');
    });

    it('returns an empty string when no meta tag exists', () => {
      document.head.innerHTML = '';

      const token = RenderAsyncController.prototype.csrfToken.call({});

      expect(token).toBe('');
    });
  });

  describe('replaceContent', () => {
    let ctx;
    let element;
    let dispatched;

    beforeEach(() => {
      document.body.innerHTML = '<div id="wrapper"><div id="async-block">old</div></div>';
      element = document.getElementById('async-block');
      dispatched = [];
      element.addEventListener('render-async:load', (e) => dispatched.push(e));

      ctx = {
        element,
        intervalValue: 0,
        parseHTML: RenderAsyncController.prototype.parseHTML
      };
    });

    it('dispatches the render-async:load event', () => {
      RenderAsyncController.prototype.replaceContent.call(ctx, '<span>new</span>');

      expect(dispatched).toHaveLength(1);
      expect(dispatched[0].type).toBe('render-async:load');
    });

    it('replaces the element entirely when interval is 0', () => {
      RenderAsyncController.prototype.replaceContent.call(ctx, '<span class="new">new</span>');

      expect(document.getElementById('async-block')).toBeNull();
      expect(document.querySelector('#wrapper span.new')).not.toBeNull();
    });

    it('swaps children but keeps the controller element when interval > 0', () => {
      ctx.intervalValue = 1000;

      RenderAsyncController.prototype.replaceContent.call(ctx, '<span class="new">new</span>');

      // Controller element must survive across refreshes for polling to keep working.
      const stillThere = document.getElementById('async-block');

      expect(stillThere).not.toBeNull();
      expect(stillThere.querySelector('span.new')).not.toBeNull();
      expect(stillThere.textContent).not.toContain('old');
    });
  });

  describe('handleError', () => {
    let ctx;
    let element;
    let dispatched;

    beforeEach(() => {
      document.body.innerHTML = '<div id="wrapper"><div id="async-block">placeholder</div></div>';
      element = document.getElementById('async-block');
      dispatched = [];
      element.addEventListener('render-async:error', (e) => dispatched.push(e));

      ctx = { element, errorMessageValue: '' };
    });

    it('dispatches a render-async:error event with the error in detail', () => {
      const err = new Error('boom');

      RenderAsyncController.prototype.handleError.call(ctx, err);

      expect(dispatched).toHaveLength(1);
      expect(dispatched[0].detail.error).toBe(err);
    });

    it('replaces the element with errorMessageValue when one is configured', () => {
      ctx.errorMessageValue = '<p class="err">failed</p>';

      RenderAsyncController.prototype.handleError.call(ctx, new Error('boom'));

      expect(document.getElementById('async-block')).toBeNull();
      expect(document.querySelector('#wrapper p.err').textContent).toBe('failed');
    });

    it('leaves the element in place when no errorMessageValue is set', () => {
      ctx.errorMessageValue = '';

      RenderAsyncController.prototype.handleError.call(ctx, new Error('boom'));

      expect(document.getElementById('async-block')).not.toBeNull();
    });
  });
});
