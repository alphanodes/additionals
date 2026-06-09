import { Controller } from '@hotwired/stimulus';

// Loads HTML asynchronously into the controller element.
// Drop-in replacement for the (unmaintained) render_async gem.
class RenderAsyncController extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 0 },
    toggleSelector: { type: String, default: '' },
    toggleEvent: { type: String, default: 'click' },
    errorMessage: { type: String, default: '' }
  };

  connect() {
    this.intervalId = null;
    this.boundLoad = this.load.bind(this);
    this.element.addEventListener('refresh', this.boundLoad);

    if (this.hasToggleSelectorValue && this.toggleSelectorValue) {
      this.toggleHandler = this.handleToggle.bind(this);
      this.toggleTargets = document.querySelectorAll(this.toggleSelectorValue);
      this.toggleTargets.forEach(target => {
        target.addEventListener(this.toggleEventValue, this.toggleHandler);
      });
    } else {
      this.load();
    }
  }

  disconnect() {
    this.stopPolling();
    this.element.removeEventListener('refresh', this.boundLoad);
    if (this.toggleTargets) {
      this.toggleTargets.forEach(target => {
        target.removeEventListener(this.toggleEventValue, this.toggleHandler);
      });
    }
  }

  handleToggle() {
    if (this.intervalId) {
      this.stopPolling();
    } else {
      this.load();
    }
  }

  load() {
    fetch(this.urlValue, {
      method: 'GET',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': this.csrfToken(),
        'Accept': 'text/html'
      },
      credentials: 'same-origin'
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`Request failed: ${response.status}`);
        }
        return response.text();
      })
      .then(html => this.replaceContent(html))
      .catch(error => this.handleError(error));

    if (this.intervalValue > 0 && this.intervalId === null) {
      this.intervalId = setInterval(this.boundLoad, this.intervalValue);
    }
  }

  replaceContent(html) {
    const event = new CustomEvent('render-async:load', { bubbles: true });
    this.element.dispatchEvent(event);

    const fragment = this.parseHTML(html);

    // Polling needs the controller element to survive across refreshes,
    // so we swap children. Otherwise we replace the element entirely.
    if (this.intervalValue > 0) {
      this.element.replaceChildren(fragment);
    } else {
      this.element.replaceWith(fragment);
    }
  }

  // Parses HTML into a DocumentFragment and re-creates <script> elements.
  // Scripts inserted via innerHTML are inert by spec; cloning them as fresh
  // script nodes makes the browser execute them.
  parseHTML(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    const fragment = template.content;

    fragment.querySelectorAll('script').forEach(oldScript => {
      const newScript = document.createElement('script');
      Array.from(oldScript.attributes).forEach(attr => {
        newScript.setAttribute(attr.name, attr.value);
      });
      newScript.text = oldScript.textContent;
      oldScript.parentNode.replaceChild(newScript, oldScript);
    });

    return fragment;
  }

  handleError(error) {
    const event = new CustomEvent('render-async:error', {
      bubbles: true,
      detail: { error }
    });
    this.element.dispatchEvent(event);

    if (this.errorMessageValue) {
      this.element.outerHTML = this.errorMessageValue;
    }
  }

  stopPolling() {
    if (this.intervalId !== null) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('render-async', RenderAsyncController);
}

export default RenderAsyncController;
