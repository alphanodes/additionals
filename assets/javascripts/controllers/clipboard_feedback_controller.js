/* global updateSVGIcon */
import { Controller } from '@hotwired/stimulus';

class ClipboardFeedbackController extends Controller {
  static values = {
    text: String,
    copiedLabel: String,
    originalTitle: String
  };

  copy(event) {
    event.preventDefault();

    if (!this.textValue) {
      return;
    }

    this.copyToClipboard(this.textValue)
      .then(() => this.showFeedback())
      .catch(() => this.showError());
  }

  // -- Feedback --

  showFeedback() {
    const icon = this.element.querySelector('svg.icon-svg');

    if (icon) {
      this.showIconFeedback();
    } else if (this.hasCopiedLabelValue) {
      this.showTooltipFeedback();
    }

    this.closeDropdown();
  }

  showIconFeedback() {
    if (typeof updateSVGIcon === 'function') {
      updateSVGIcon(this.element, 'checked');
      setTimeout(() => updateSVGIcon(this.element, 'copy'), 2000);
    }
  }

  showTooltipFeedback() {
    const original = this.element.getAttribute('title');
    this.element.setAttribute('title', this.copiedLabelValue);

    if (typeof $ !== 'undefined' && typeof $.fn.tooltip !== 'undefined') {
      $(this.element).tooltip('destroy');
      $(this.element).tooltip({ show: { delay: 400 }, position: { my: 'center bottom-5', at: 'center top' } });
      $(this.element).trigger('mouseenter');
    }

    setTimeout(() => {
      if (typeof $ !== 'undefined' && typeof $.fn.tooltip !== 'undefined') {
        $(this.element).trigger('mouseleave');
      }
      this.element.setAttribute('title', original);
      if (typeof $ !== 'undefined' && typeof $.fn.tooltip !== 'undefined') {
        $(this.element).tooltip('destroy');
        $(this.element).tooltip({ show: { delay: 400 }, position: { my: 'center bottom-5', at: 'center top' } });
      }
    }, 2000);
  }

  showError() {
    console.error('Failed to copy to clipboard');
  }

  // -- Helpers --

  copyToClipboard(text) {
    if (navigator.clipboard) {
      return navigator.clipboard.writeText(text);
    }

    // Fallback for older browsers
    if (typeof window.copyToClipboard === 'function') {
      return window.copyToClipboard(text);
    }

    return Promise.reject(new Error('Clipboard API not available'));
  }

  closeDropdown() {
    const dropdown = this.element.closest('.drdn.expanded');
    if (dropdown) {
      dropdown.classList.remove('expanded');
    }
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('clipboard-feedback', ClipboardFeedbackController);
}

export default ClipboardFeedbackController;
