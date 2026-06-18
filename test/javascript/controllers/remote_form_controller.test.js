import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import RemoteFormController from '../../../assets/javascripts/controllers/remote_form_controller.js';

describe('RemoteFormController', () => {
  describe('submit', () => {
    it('delegates to send() with the form url, method and FormData', () => {
      document.body.innerHTML = '<form id="f" method="POST" action="/post-me"><input name="x" value="1"></form>';
      const form = document.getElementById('f');
      const sendCalls = [];
      const ctx = {
        element: form,
        send(url, method, body) { sendCalls.push({ url, method, body }); },
      };

      RemoteFormController.prototype.submit.call(ctx, { preventDefault: () => {} });

      expect(sendCalls).toHaveLength(1);
      expect(sendCalls[0].method).toBe('POST');
      expect(sendCalls[0].url).toContain('/post-me');
      expect(sendCalls[0].body).toBeInstanceOf(FormData);
    });
  });

  describe('click', () => {
    let sendCalls;
    let confirmSpy;

    beforeEach(() => {
      sendCalls = [];
      confirmSpy = vi.spyOn(window, 'confirm');
    });

    afterEach(() => {
      confirmSpy.mockRestore();
    });

    const linkWith = (attrs = {}) => {
      const a = document.createElement('a');
      Object.entries(attrs).forEach(([k, v]) => a.setAttribute(k, v));
      a.href = attrs.href || '/delete-me';
      return a;
    };

    const ctxFor = (link) => ({
      element: link,
      send(url, method, body) { sendCalls.push({ url, method, body }); },
    });

    it('sends with data-remote-method as uppercase', () => {
      const link = linkWith({ 'data-remote-method': 'delete' });

      RemoteFormController.prototype.click.call(ctxFor(link), { preventDefault: () => {} });

      expect(sendCalls).toHaveLength(1);
      expect(sendCalls[0].method).toBe('DELETE');
      expect(sendCalls[0].body).toBeNull();
    });

    it('defaults to GET when no data-remote-method set', () => {
      const link = linkWith({});

      RemoteFormController.prototype.click.call(ctxFor(link), { preventDefault: () => {} });

      expect(sendCalls[0].method).toBe('GET');
    });

    it('aborts when confirm dialog is declined', () => {
      confirmSpy.mockReturnValue(false);
      const link = linkWith({ 'data-remote-confirm': 'Sure?', 'data-remote-method': 'delete' });

      RemoteFormController.prototype.click.call(ctxFor(link), { preventDefault: () => {} });

      expect(confirmSpy).toHaveBeenCalledWith('Sure?');
      expect(sendCalls).toHaveLength(0);
    });

    it('proceeds when confirm dialog is accepted', () => {
      confirmSpy.mockReturnValue(true);
      const link = linkWith({ 'data-remote-confirm': 'Sure?', 'data-remote-method': 'delete' });

      RemoteFormController.prototype.click.call(ctxFor(link), { preventDefault: () => {} });

      expect(confirmSpy).toHaveBeenCalled();
      expect(sendCalls).toHaveLength(1);
    });

    it('ignores rails-ujs style data-confirm so it cannot trigger a second dialog', () => {
      const link = linkWith({ 'data-confirm': 'Sure?', 'data-method': 'delete' });

      RemoteFormController.prototype.click.call(ctxFor(link), { preventDefault: () => {} });

      expect(confirmSpy).not.toHaveBeenCalled();
      expect(sendCalls[0].method).toBe('GET');
    });
  });

  describe('applyDirectives', () => {
    let element;
    let ctx;
    let dispatched;

    beforeEach(() => {
      document.body.innerHTML = '<div id="ajax-indicator" style="display:none"></div><form id="my-form"></form><div id="container"><div id="block-foo">old foo</div><div id="block-bar">old bar</div></div>';
      element = document.getElementById('my-form');
      dispatched = [];
      element.addEventListener('remote-form:success', e => dispatched.push(e));

      ctx = {
        element,
        execute: RemoteFormController.prototype.execute,
      };
    });

    it('replaces the target with template content', () => {
      const html = '<template data-remote-update-action="replace" data-remote-update-target="#block-foo"><div id="block-foo" class="updated">new foo</div></template>';

      RemoteFormController.prototype.applyDirectives.call(ctx, html);

      const updated = document.querySelector('#block-foo.updated');

      expect(updated).not.toBeNull();
      expect(updated.textContent).toBe('new foo');
    });

    it('iterates multiple directives in order', () => {
      const html = '<template data-remote-update-action="replace" data-remote-update-target="#block-foo"><div id="block-foo">new foo</div></template><template data-remote-update-action="replace" data-remote-update-target="#block-bar"><div id="block-bar">new bar</div></template>';

      RemoteFormController.prototype.applyDirectives.call(ctx, html);

      expect(document.getElementById('block-foo').textContent).toBe('new foo');
      expect(document.getElementById('block-bar').textContent).toBe('new bar');
    });

    it('dispatches remote-form:success after applying directives', () => {
      RemoteFormController.prototype.applyDirectives.call(ctx, '');

      expect(dispatched).toHaveLength(1);
      expect(dispatched[0].type).toBe('remote-form:success');
    });

    it('falls back to document when controller element got detached by the directive', () => {
      // The form lives inside one of the replaced containers.
      document.body.innerHTML = '<div id="container"><form id="my-form"></form></div>';
      const innerForm = document.getElementById('my-form');
      const documentEvents = [];
      document.addEventListener('remote-form:success', e => documentEvents.push(e), { once: true });

      const swapHtml = '<template data-remote-update-action="replace" data-remote-update-target="#container"><div id="container"><span>new</span></div></template>';

      RemoteFormController.prototype.applyDirectives.call({ element: innerForm, execute: RemoteFormController.prototype.execute }, swapHtml);

      expect(innerForm.isConnected).toBe(false);
      expect(documentEvents).toHaveLength(1);
    });

    it('skips directives without target', () => {
      const html = '<template data-remote-update-action="replace"><div>orphaned directive</div></template>';

      RemoteFormController.prototype.applyDirectives.call(ctx, html);

      expect(document.body.textContent).not.toContain('orphaned directive');
    });

    it('passes through any non-template content untouched', () => {
      const before = document.getElementById('block-foo').textContent;
      const html = '<p>just some HTML, no directives</p>';

      RemoteFormController.prototype.applyDirectives.call(ctx, html);

      expect(document.getElementById('block-foo').textContent).toBe(before);
    });
  });

  describe('execute', () => {
    let target;

    beforeEach(() => {
      document.body.innerHTML = '<div id="wrap"><div id="t">original</div></div>';
      target = document.getElementById('t');
    });

    const directive = (html) => {
      const tmpl = document.createElement('template');
      tmpl.innerHTML = html;
      return tmpl;
    };

    it('replace swaps the target element entirely', () => {
      RemoteFormController.prototype.execute.call({},
        'replace', target, directive('<span class="new">x</span>'));

      expect(document.getElementById('t')).toBeNull();
      expect(document.querySelector('#wrap span.new').textContent).toBe('x');
    });

    it('prepend inserts content as the first child', () => {
      RemoteFormController.prototype.execute.call({},
        'prepend', target, directive('<span class="new">first</span>'));

      const t = document.getElementById('t');

      expect(t.firstElementChild.textContent).toBe('first');
      expect(t.textContent).toContain('original');
    });

    it('append inserts content as the last child', () => {
      RemoteFormController.prototype.execute.call({},
        'append', target, directive('<span class="new">last</span>'));

      const t = document.getElementById('t');

      expect(t.lastElementChild.textContent).toBe('last');
      expect(t.textContent).toContain('original');
    });

    it('inner replaces all children but keeps the target element', () => {
      RemoteFormController.prototype.execute.call({},
        'inner', target, directive('<span class="new">inner</span>'));

      const t = document.getElementById('t');

      expect(t).not.toBeNull();
      expect(t.textContent).toBe('inner');
    });

    it('remove deletes the target element', () => {
      RemoteFormController.prototype.execute.call({},
        'remove', target, directive(''));

      expect(document.getElementById('t')).toBeNull();
    });

    it('warns about unknown action and does nothing', () => {
      const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      RemoteFormController.prototype.execute.call({},
        'destroy-the-page', target, directive('<span>nope</span>'));

      expect(warn).toHaveBeenCalledWith(expect.stringContaining('destroy-the-page'));
      expect(document.getElementById('t')).not.toBeNull();
      warn.mockRestore();
    });
  });

  describe('handleError', () => {
    let element;
    let dispatched;

    beforeEach(() => {
      document.body.innerHTML = '<form id="f"></form>';
      element = document.getElementById('f');
      dispatched = [];
      element.addEventListener('remote-form:error', e => dispatched.push(e));
    });

    it('dispatches remote-form:error with the error in detail', () => {
      const err = new Error('boom');

      RemoteFormController.prototype.handleError.call({ element }, err);

      expect(dispatched).toHaveLength(1);
      expect(dispatched[0].detail.error).toBe(err);
    });
  });

  describe('loading indicator', () => {
    let indicator;

    beforeEach(() => {
      document.body.innerHTML = '<div id="ajax-indicator" style="display:none"></div>';
      indicator = document.getElementById('ajax-indicator');
    });

    afterEach(() => {
      document.body.innerHTML = '';
    });

    it('showIndicator clears the inline display style', () => {
      RemoteFormController.prototype.showIndicator.call({});

      expect(indicator.style.display).toBe('');
    });

    it('hideIndicator sets display:none', () => {
      indicator.style.display = '';

      RemoteFormController.prototype.hideIndicator.call({});

      expect(indicator.style.display).toBe('none');
    });

    it('is a no-op when no indicator exists in DOM', () => {
      document.body.innerHTML = '';

      // Should not throw.
      RemoteFormController.prototype.showIndicator.call({});
      RemoteFormController.prototype.hideIndicator.call({});
    });
  });

  describe('csrfToken', () => {
    afterEach(() => {
      document.head.innerHTML = '';
    });

    it('reads the csrf-token meta tag', () => {
      document.head.innerHTML = '<meta name="csrf-token" content="xyz">';

      const token = RemoteFormController.prototype.csrfToken.call({});

      expect(token).toBe('xyz');
    });

    it('returns empty string when no meta tag exists', () => {
      document.head.innerHTML = '';

      const token = RemoteFormController.prototype.csrfToken.call({});

      expect(token).toBe('');
    });
  });
});
