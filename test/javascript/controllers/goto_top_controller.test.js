import { describe, it, expect, beforeEach, vi } from 'vitest';
import GotoTopController from '../../../assets/javascripts/controllers/goto_top_controller.js';

describe('GotoTopController', () => {
  describe('connect', () => {
    it('adds cursor and title to sticky header', () => {
      document.body.innerHTML = `
        <a id="anchor" data-label="Nach oben"></a>
        <div id="sticky-issue-header"></div>
      `;

      const ctx = {
        element: document.getElementById('anchor'),
        scrollToTop: GotoTopController.prototype.scrollToTop
      };

      GotoTopController.prototype.connect.call(ctx);

      const header = document.getElementById('sticky-issue-header');

      expect(header.style.cursor).toBe('pointer');
      expect(header.getAttribute('title')).toBe('Nach oben');
    });

    it('does nothing when sticky header is absent', () => {
      document.body.innerHTML = '<a id="anchor" data-label="Top"></a>';

      const ctx = {
        element: document.getElementById('anchor'),
        scrollToTop: GotoTopController.prototype.scrollToTop
      };

      // Should not throw
      GotoTopController.prototype.connect.call(ctx);

      expect(ctx.stickyHeader).toBeUndefined();
    });

    it('uses fallback label when data-label is missing', () => {
      document.body.innerHTML = `
        <a id="anchor"></a>
        <div id="sticky-issue-header"></div>
      `;

      const ctx = {
        element: document.getElementById('anchor'),
        scrollToTop: GotoTopController.prototype.scrollToTop
      };

      GotoTopController.prototype.connect.call(ctx);

      expect(document.getElementById('sticky-issue-header').getAttribute('title')).toBe('Go to top');
    });
  });

  describe('disconnect', () => {
    it('removes cursor and title from sticky header', () => {
      document.body.innerHTML = `
        <a id="anchor" data-label="Top"></a>
        <div id="sticky-issue-header" style="cursor: pointer" title="Top"></div>
      `;

      const header = document.getElementById('sticky-issue-header');
      const ctx = {
        stickyHeader: header,
        boundClick: vi.fn()
      };

      GotoTopController.prototype.disconnect.call(ctx);

      expect(header.style.cursor).toBe('');
      expect(header.getAttribute('title')).toBeNull();
    });

    it('does nothing when stickyHeader is null', () => {
      const ctx = { stickyHeader: null };

      // Should not throw
      GotoTopController.prototype.disconnect.call(ctx);
    });
  });

  describe('scrollToTop', () => {
    it('scrolls to top smoothly', () => {
      const scrollSpy = vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
      const event = { preventDefault: vi.fn() };

      GotoTopController.prototype.scrollToTop.call({}, event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(scrollSpy).toHaveBeenCalledWith({ top: 0, behavior: 'smooth' });
    });
  });
});
