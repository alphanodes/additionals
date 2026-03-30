import { Controller } from '@hotwired/stimulus';

class LiveSearchController extends Controller {
  static values = {
    url: String,
    target: String
  };

  connect() {
    this.element.classList.add('livesearch');
    this.lastValue = this.element.value || '';
    this.debounceTimer = null;
  }

  disconnect() {
    clearTimeout(this.debounceTimer);
  }

  onInput() {
    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => this.performSearch(), 400);
  }

  performSearch() {
    const val = this.element.value;
    if (val === this.lastValue) {
      return;
    }
    this.lastValue = val;

    const form = document.getElementById('query_form');
    let url;
    let data;

    if (this.hasUrlValue) {
      url = this.urlValue;
      data = new URLSearchParams({ q: val });
    } else if (form) {
      // Temporarily select all columns for the request
      this.selectAllColumns(form, true);
      url = form.getAttribute('action');
      data = new URLSearchParams(new FormData(form));
      this.selectAllColumns(form, false);
    } else {
      return;
    }

    this.element.classList.add('ajax-loading');

    fetch(`${url}?${data}`, {
      headers: { 'X-Requested-With': 'XMLHttpRequest' }
    })
      .then(response => response.text())
      .then(html => {
        const targetId = this.hasTargetValue ? this.targetValue : 'query-result-list';
        const targetEl = document.getElementById(targetId);
        if (targetEl) {
          targetEl.innerHTML = html;
        }
      })
      .finally(() => {
        this.element.classList.remove('ajax-loading');
      });
  }

  selectAllColumns(form, selected) {
    form.querySelectorAll('[name="c[]"] option').forEach(opt => {
      opt.selected = selected;
    });
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('live-search', LiveSearchController);
}

export default LiveSearchController;
