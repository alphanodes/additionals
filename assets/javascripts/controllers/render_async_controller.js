import { Controller } from '@hotwired/stimulus';

// Loads HTML asynchronously into the controller element.
// Drop-in replacement for the (unmaintained) render_async gem.
class RenderAsyncController extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 0 },
    toggleSelector: { type: String, default: '' },
    toggleEvent: { type: String, default: 'click' },
    errorMessage: { type: String, default: '' },
    lazy: { type: Boolean, default: false },
  };

  connect() {
    this.intervalId = null;
    this.boundLoad = this.load.bind(this);
    this.element.addEventListener('refresh', this.boundLoad);

    // Pause polling while the tab is hidden, refresh immediately when it
    // returns. Only relevant for auto-refresh blocks.
    if (this.intervalValue > 0) {
      this.boundVisibilityChange = this.handleVisibilityChange.bind(this);
      document.addEventListener('visibilitychange', this.boundVisibilityChange);
    }

    if (this.hasToggleSelectorValue && this.toggleSelectorValue) {
      this.toggleHandler = this.handleToggle.bind(this);
      this.toggleTargets = document.querySelectorAll(this.toggleSelectorValue);
      this.toggleTargets.forEach(target => {
        target.addEventListener(this.toggleEventValue, this.toggleHandler);
      });
    } else if (this.lazyValue) {
      this.observeLazyTrigger();
    } else {
      this.load();
    }
  }

  disconnect() {
    this.stopPolling();
    this.disconnectLazyObserver();
    this.element.removeEventListener('refresh', this.boundLoad);
    if (this.boundVisibilityChange) {
      document.removeEventListener('visibilitychange', this.boundVisibilityChange);
    }
    if (this.toggleTargets) {
      this.toggleTargets.forEach(target => {
        target.removeEventListener(this.toggleEventValue, this.toggleHandler);
      });
    }
  }

  // Defers load() until the controller element scrolls into the viewport.
  // rootMargin pre-loads 200px before the element enters the viewport so the
  // user does not see a perceptible delay.
  observeLazyTrigger() {
    this.lazyObserver = new IntersectionObserver(entries => {
      if (entries.some(e => e.isIntersecting)) {
        this.disconnectLazyObserver();
        this.load();
      }
    }, { rootMargin: '200px' });
    this.lazyObserver.observe(this.element);
  }

  disconnectLazyObserver() {
    if (this.lazyObserver) {
      this.lazyObserver.disconnect();
      this.lazyObserver = null;
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stopPolling();
    } else if (this.intervalId === null) {
      // Tab is visible again - load immediately and resume polling.
      this.load();
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
    // An external `refresh` event can fire before the lazy observer triggers.
    // Stop observing once we are loading anyway.
    this.disconnectLazyObserver();
    fetch(this.urlValue, {
      method: 'GET',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': this.csrfToken(),
        Accept: 'text/html',
      },
      credentials: 'same-origin',
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
  //
  // Inline scripts execute immediately on insertion and do NOT wait for any
  // preceding external script with `async = false`. To guarantee that an inline
  // call like `RedmineReporting.renderChart(...)` runs after its external
  // `burndown_chart.js` dependency, we strip inline scripts from the fragment
  // and re-inject them after the external script's load event fires.
  parseHTML(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    const fragment = template.content;

    let waitForExternal = Promise.resolve();

    fragment.querySelectorAll('script').forEach(oldScript => {
      if (oldScript.src) {
        const newScript = document.createElement('script');
        Array.from(oldScript.attributes).forEach(attr => {
          newScript.setAttribute(attr.name, attr.value);
        });
        newScript.async = false;
        waitForExternal = new Promise(resolve => {
          newScript.addEventListener('load', resolve, { once: true });
          newScript.addEventListener('error', resolve, { once: true });
        });
        oldScript.parentNode.replaceChild(newScript, oldScript);
      } else {
        const scriptText = oldScript.textContent;
        // Remove from fragment so it does not auto-execute on insert.
        oldScript.remove();
        // Re-run after the most recent external script in this batch loaded.
        waitForExternal.then(() => {
          const newScript = document.createElement('script');
          newScript.text = scriptText;
          document.body.appendChild(newScript);
          newScript.remove();
        });
      }
    });

    return fragment;
  }

  handleError(error) {
    const event = new CustomEvent('render-async:error', {
      bubbles: true,
      detail: { error },
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
