/* global AdditionalsWikiToolbar, jsToolBar */
import {
  describe, it, expect, vi, beforeEach, afterEach,
} from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Classic script, executed in global scope like in the browser
const scriptPath = resolve(__dirname, '../../assets/javascripts/additionals_wiki_toolbar.js');
const globalEval = eval; // eslint-disable-line no-eval
globalEval(readFileSync(scriptPath, 'utf-8'));

// Toolbar as Redmine 7.1 renders it (https://www.redmine.org/issues/43259)
function serverToolbar(fieldId) {
  return `
    <div class="jstBlock" data-controller="wiki-toolbar" data-wiki-toolbar-field-id-value="${fieldId}">
      <div class="jstTabs tabs"><ul><li class="tab-elements">
        <div class="jstElements"><button type="button" class="jstb_strong"><span>Bold</span></button><button type="button" class="jstb_help"><span>Help</span></button></div>
      </li></ul></div>
      <div class="jstEditor"><textarea id="${fieldId}">Some text</textarea></div>
    </div>`;
}

// Toolbar as the jsToolBar of Redmine 7.0 draws it
function jsToolBarToolbar(fieldId) {
  return `
    <div class="jstBlock">
      <div class="jstTabs tabs"><ul><li class="tab-elements"><div class="jstElements"></div></li></ul></div>
      <div class="jstEditor"><textarea id="${fieldId}">Some text</textarea></div>
    </div>`;
}

const flush = () => new Promise((done) => { setTimeout(done, 0); });

describe('AdditionalsWikiToolbar', () => {
  let name;
  let counter = 0;

  beforeEach(() => {
    counter += 1;
    name = `test_button_${counter}`;
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('puts a registered button into the server rendered toolbar', () => {
    document.body.innerHTML = serverToolbar('issue_notes');

    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn() });

    const button = document.querySelector(`.jstElements .jstb_${name}`);
    expect(button.nextElementSibling.className).toBe('jstb_help');
    expect(button.title).toBe('Test');
    expect(button.textContent).toBe('Test');
    expect(document.querySelectorAll(`.jstb_${name}`)).toHaveLength(1);
  });

  it('puts it into the toolbar of the jsToolBar as well', () => {
    document.body.innerHTML = jsToolBarToolbar('wiki_text');

    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn() });

    expect(document.querySelector(`.jstElements .jstb_${name}`)).not.toBeNull();
  });

  it('hands the textarea of its toolbar to the click', () => {
    document.body.innerHTML = serverToolbar('first') + serverToolbar('second');
    const onClick = vi.fn();

    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick });
    document.querySelectorAll(`.jstb_${name}`)[1].click();

    expect(onClick).toHaveBeenCalledTimes(1);
    expect(onClick.mock.calls[0][0].textarea.id).toBe('second');
  });

  it('leaves out toolbars the button is not available for', () => {
    document.body.innerHTML = serverToolbar('first') + serverToolbar('second');

    AdditionalsWikiToolbar.register(name, {
      title: 'Test', onClick: vi.fn(), available: (textarea) => textarea.id === 'second',
    });

    expect(document.querySelectorAll(`.jstb_${name}`)).toHaveLength(1);
    expect(document.querySelector(`.jstb_${name}`).closest('.jstBlock').dataset.wikiToolbarFieldIdValue).toBe('second');
  });

  it('puts the button into toolbars added later, once', async () => {
    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn() });

    document.body.insertAdjacentHTML('beforeend', serverToolbar('loaded_later'));
    await flush();

    expect(document.querySelectorAll(`.jstb_${name}`)).toHaveLength(1);
  });

  it('puts the button back when the buttons of a toolbar are drawn again', async () => {
    document.body.innerHTML = serverToolbar('redrawn');
    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn() });

    const toolbar = document.querySelector('.jstElements');
    toolbar.replaceChildren();
    toolbar.insertAdjacentHTML('beforeend', '<button type="button" class="jstb_strong"><span>Bold</span></button>');
    await flush();

    expect(toolbar.querySelectorAll(`.jstb_${name}`)).toHaveLength(1);
  });

  // Like the buttons of core: each case one textarea text, selection and result
  it('wraps the selection like core does', () => {
    document.body.innerHTML = serverToolbar('wrapped');
    const textarea = document.getElementById('wrapped');
    const input = vi.fn();
    textarea.addEventListener('input', input);

    [
      // text, selection, value, cursor
      ['Some text', [5, 9], 'Some {{m(text)}}', 16],
      ['Some text', [9, 9], 'Some text {{m()}}', 14],
      ['Sometext', [4, 4], 'Some {{m()}} text', 9],
      ['Some text ', [5, 10], 'Some {{m(text)}} ', 17],
    ].forEach(([text, [from, to], value, cursor]) => {
      textarea.value = text;
      textarea.setSelectionRange(from, to);

      AdditionalsWikiToolbar.wrapSelection(textarea, '{{m(', ')}}');

      expect([textarea.value, textarea.selectionStart, textarea.selectionEnd]).toEqual([value, cursor, cursor]);
    });
    expect(input).toHaveBeenCalledTimes(4);
  });

  it('replaces the selection, the cursor behind the text', () => {
    document.body.innerHTML = serverToolbar('replaced');
    const textarea = document.getElementById('replaced');
    textarea.setSelectionRange(5, 9);

    AdditionalsWikiToolbar.replaceSelection(textarea, 'answer');

    expect(textarea.value).toBe('Some answer');
    expect(textarea.selectionStart).toBe(11);
    expect(textarea.selectionEnd).toBe(11);
  });

  // For an editor of its own, which offers the buttons in its toolbar
  it('hands out the registered buttons and a context for a textarea', () => {
    document.body.innerHTML = serverToolbar('own_editor');
    const onClick = vi.fn();
    AdditionalsWikiToolbar.register(name, { title: 'Test', onClick });

    const [, definition] = AdditionalsWikiToolbar.definitions().find(([registered]) => registered === name);
    const textarea = document.getElementById('own_editor');
    textarea.setSelectionRange(0, 4);
    const context = AdditionalsWikiToolbar.contextFor(textarea, 'the button');
    context.wrapSelection('*', '*');

    expect(definition.onClick).toBe(onClick);
    expect(context.button).toBe('the button');
    expect(textarea.value).toBe('*Some* text');
  });

  // TODO(Redmine 7.0 EOL): the jsToolBar and the visual editor take the button from its prototype
  describe('with jsToolBar', () => {
    beforeEach(() => {
      globalThis.jsToolBar = function jsToolBar() {};
      globalThis.jsToolBar.prototype.elements = {};
    });

    afterEach(() => {
      delete globalThis.jsToolBar;
    });

    it('adds the button to the elements of the jsToolBar', () => {
      const onClick = vi.fn();
      AdditionalsWikiToolbar.register(name, { title: 'Test', onClick });

      const element = jsToolBar.prototype.elements[name];
      const toolbar = { textarea: 'the textarea', toolNodes: { [name]: 'the button' }, encloseSelection: vi.fn() };
      element.fn.wiki.call(toolbar);
      onClick.mock.calls[0][0].wrapSelection('<', '>');
      onClick.mock.calls[0][0].replaceSelection('text');

      expect(element.title).toBe('Test');
      expect(onClick.mock.calls[0][0].textarea).toBe('the textarea');
      expect(onClick.mock.calls[0][0].button).toBe('the button');
      expect(toolbar.encloseSelection).toHaveBeenCalledWith('<', '>');
      expect(toolbar.encloseSelection.mock.calls[1][2]()).toBe('text');
    });

    // A plugin head registers before :header_tags loads the jsToolBar
    it('adds the button once the jsToolBar is there', () => {
      const jsToolBarOfCore = globalThis.jsToolBar;
      delete globalThis.jsToolBar;
      Object.defineProperty(document, 'readyState', { value: 'loading', configurable: true });

      AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn() });
      globalThis.jsToolBar = jsToolBarOfCore;
      delete document.readyState;
      document.dispatchEvent(new Event('DOMContentLoaded'));

      expect(jsToolBar.prototype.elements[name].title).toBe('Test');
    });

    it('keeps a button for some textareas out of the elements', () => {
      AdditionalsWikiToolbar.register(name, { title: 'Test', onClick: vi.fn(), available: () => true });

      expect(jsToolBar.prototype.elements[name]).toBeUndefined();
    });
  });
});
