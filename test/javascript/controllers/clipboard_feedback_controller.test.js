import { describe, it, expect, beforeEach, vi } from 'vitest';
import ClipboardFeedbackController from '../../../assets/javascripts/controllers/clipboard_feedback_controller.js';

describe('ClipboardFeedbackController', () => {
  describe('static declarations', () => {
    it('declares expected values', () => {
      expect(ClipboardFeedbackController.values.text).toBe(String);
      expect(ClipboardFeedbackController.values.copiedLabel).toBe(String);
      expect(ClipboardFeedbackController.values.originalTitle).toBe(String);
    });
  });

  describe('copy', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = '<button id="btn">Copy</button>';

      ctx = {
        element: document.getElementById('btn'),
        textValue: 'hello world',
        hasCopiedLabelValue: false,
        copiedLabelValue: '',
        copyToClipboard: vi.fn().mockResolvedValue(),
        showFeedback: vi.fn(),
        showError: vi.fn()
      };
    });

    it('copies text and shows feedback', async () => {
      const event = { preventDefault: vi.fn() };
      await ClipboardFeedbackController.prototype.copy.call(ctx, event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(ctx.copyToClipboard).toHaveBeenCalledWith('hello world');
    });

    it('does nothing when text is empty', async () => {
      ctx.textValue = '';
      const event = { preventDefault: vi.fn() };
      await ClipboardFeedbackController.prototype.copy.call(ctx, event);

      expect(ctx.copyToClipboard).not.toHaveBeenCalled();
    });

    it('calls showError on clipboard failure', async () => {
      ctx.copyToClipboard = vi.fn().mockRejectedValue(new Error('fail'));
      const event = { preventDefault: vi.fn() };
      ClipboardFeedbackController.prototype.copy.call(ctx, event);

      // Wait for promise rejection to propagate
      await new Promise(resolve => { setTimeout(resolve, 0); });

      expect(ctx.showError).toHaveBeenCalled();
    });
  });

  describe('showIconFeedback', () => {
    let ctx;

    beforeEach(() => {
      document.body.innerHTML = '<button id="btn"><svg class="icon-svg"></svg></button>';
      ctx = { element: document.getElementById('btn') };
      globalThis.updateSVGIcon = vi.fn();
    });

    it('calls updateSVGIcon with checked', () => {
      ClipboardFeedbackController.prototype.showIconFeedback.call(ctx);

      expect(updateSVGIcon).toHaveBeenCalledWith(ctx.element, 'checked');
    });

    it('reverts to copy icon after timeout', () => {
      vi.useFakeTimers();
      ClipboardFeedbackController.prototype.showIconFeedback.call(ctx);
      vi.advanceTimersByTime(2000);

      expect(updateSVGIcon).toHaveBeenCalledWith(ctx.element, 'copy');
      vi.useRealTimers();
    });
  });

  describe('closeDropdown', () => {
    it('removes expanded class from parent dropdown', () => {
      document.body.innerHTML = '<div class="drdn expanded"><button id="btn">Copy</button></div>';
      const ctx = { element: document.getElementById('btn') };

      ClipboardFeedbackController.prototype.closeDropdown.call(ctx);

      expect(document.querySelector('.drdn').classList.contains('expanded')).toBe(false);
    });

    it('does nothing when not inside dropdown', () => {
      document.body.innerHTML = '<button id="btn">Copy</button>';
      const ctx = { element: document.getElementById('btn') };

      // Should not throw
      ClipboardFeedbackController.prototype.closeDropdown.call(ctx);
    });
  });

  describe('copyToClipboard', () => {
    it('uses navigator.clipboard when available', async () => {
      const writeText = vi.fn().mockResolvedValue();
      Object.defineProperty(navigator, 'clipboard', { value: { writeText }, writable: true });

      const ctx = {};
      await ClipboardFeedbackController.prototype.copyToClipboard.call(ctx, 'test');

      expect(writeText).toHaveBeenCalledWith('test');
    });

    it('falls back to window.copyToClipboard', async () => {
      Object.defineProperty(navigator, 'clipboard', { value: undefined, writable: true });
      window.copyToClipboard = vi.fn().mockResolvedValue();

      const ctx = {};
      await ClipboardFeedbackController.prototype.copyToClipboard.call(ctx, 'test');

      expect(window.copyToClipboard).toHaveBeenCalledWith('test');
    });

    it('rejects when no clipboard API available', async () => {
      Object.defineProperty(navigator, 'clipboard', { value: undefined, writable: true });
      delete window.copyToClipboard;

      const ctx = {};

      await expect(ClipboardFeedbackController.prototype.copyToClipboard.call(ctx, 'test'))
        .rejects.toThrow('Clipboard API not available');
    });
  });

  describe('showFeedback', () => {
    it('calls showIconFeedback when icon element exists', () => {
      document.body.innerHTML = '<button id="btn"><svg class="icon-svg"></svg></button>';
      const ctx = {
        element: document.getElementById('btn'),
        hasCopiedLabelValue: false,
        showIconFeedback: vi.fn(),
        showTooltipFeedback: vi.fn(),
        closeDropdown: vi.fn()
      };

      ClipboardFeedbackController.prototype.showFeedback.call(ctx);

      expect(ctx.showIconFeedback).toHaveBeenCalled();
      expect(ctx.showTooltipFeedback).not.toHaveBeenCalled();
    });

    it('calls showTooltipFeedback when no icon but copiedLabel exists', () => {
      document.body.innerHTML = '<button id="btn">Copy</button>';
      const ctx = {
        element: document.getElementById('btn'),
        hasCopiedLabelValue: true,
        showIconFeedback: vi.fn(),
        showTooltipFeedback: vi.fn(),
        closeDropdown: vi.fn()
      };

      ClipboardFeedbackController.prototype.showFeedback.call(ctx);

      expect(ctx.showTooltipFeedback).toHaveBeenCalled();
      expect(ctx.showIconFeedback).not.toHaveBeenCalled();
    });

    it('always calls closeDropdown', () => {
      document.body.innerHTML = '<button id="btn">Copy</button>';
      const ctx = {
        element: document.getElementById('btn'),
        hasCopiedLabelValue: false,
        showIconFeedback: vi.fn(),
        showTooltipFeedback: vi.fn(),
        closeDropdown: vi.fn()
      };

      ClipboardFeedbackController.prototype.showFeedback.call(ctx);

      expect(ctx.closeDropdown).toHaveBeenCalled();
    });
  });
});
