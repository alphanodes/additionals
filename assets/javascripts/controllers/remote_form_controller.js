import { Controller } from '@hotwired/stimulus';

// Submits the controlled form via fetch and applies <template>-based DOM
// directives from the server response. Drop-in replacement for the
// rails-ujs `form_tag remote: true` + `*.js.erb` pattern.
//
// Server response format:
//   <template data-remote-update-action="replace"
//             data-remote-update-target="#block-foo">
//     <div id="block-foo">new content</div>
//   </template>
//
// Supported actions: replace, prepend, append, inner, remove.
class RemoteFormController extends Controller {
  submit(event) {
    event.preventDefault();
    const form = this.element;
    this.send(form.action, (form.method || 'POST').toUpperCase(), new FormData(form));
  }

  click(event) {
    event.preventDefault();
    const link = this.element;
    // Use plugin-prefixed dataset keys so we don't collide with rails-ujs,
    // which delegates on `a[data-confirm]` / `a[data-method]` at document level.
    const confirmMessage = link.dataset.remoteConfirm;
    if (confirmMessage && !window.confirm(confirmMessage)) { return; }
    const method = (link.dataset.remoteMethod || 'GET').toUpperCase();
    this.send(link.href, method, null);
  }

  send(url, method, body) {
    this.showIndicator();
    fetch(url, {
      method,
      body,
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
      .then(html => this.applyDirectives(html))
      .catch(error => this.handleError(error))
      .finally(() => this.hideIndicator());
  }

  applyDirectives(html) {
    const wrapper = document.createElement('template');
    wrapper.innerHTML = html;

    wrapper.content.querySelectorAll('template[data-remote-update-action]').forEach(directive => {
      const action = directive.dataset.remoteUpdateAction;
      const selector = directive.dataset.remoteUpdateTarget;
      if (!selector) { return; }

      document.querySelectorAll(selector).forEach(target => {
        this.execute(action, target, directive);
      });
    });

    // If the form was inside one of the replaced containers, this.element is now
    // detached and events dispatched on it would not bubble to the document.
    const dispatchTarget = this.element.isConnected ? this.element : document;
    const event = new CustomEvent('remote-form:success', { bubbles: true });
    dispatchTarget.dispatchEvent(event);
  }

  execute(action, target, directive) {
    const fragment = directive.content.cloneNode(true);

    switch (action) {
    case 'replace':
      target.replaceWith(...fragment.childNodes);
      break;
    case 'prepend':
      target.prepend(fragment);
      break;
    case 'append':
      target.append(fragment);
      break;
    case 'inner':
      target.replaceChildren(fragment);
      break;
    case 'remove':
      target.remove();
      break;
    default:
      // Unknown action - emit a warning, do nothing.
      if (typeof console !== 'undefined') {
        console.warn(`remote-form: unknown action "${action}"`);
      }
    }
  }

  handleError(error) {
    const event = new CustomEvent('remote-form:error', {
      bubbles: true,
      detail: { error }
    });
    this.element.dispatchEvent(event);
  }

  showIndicator() {
    const indicator = document.getElementById('ajax-indicator');
    if (indicator) { indicator.style.display = ''; }
  }

  hideIndicator() {
    const indicator = document.getElementById('ajax-indicator');
    if (indicator) { indicator.style.display = 'none'; }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('remote-form', RemoteFormController);
}

export default RemoteFormController;
