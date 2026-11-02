import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { Application } from '@hotwired/stimulus';
import jQuery from 'jquery';
import AdditionalsSelectController, {
  AdditionalsSelect, RENDERERS, tagGroup, withoutScopedSiblings, createTag, resultsWithValueKey,
} from '../../../assets/javascripts/controllers/additionals_select_controller.js';

// The controller is tested against the real library, as the pages use it: its
// job is the translation between our interface and the library, which a mock
// of the library could not show.
globalThis.jQuery = jQuery;
globalThis.$ = jQuery;
const globalEval = eval; // eslint-disable-line no-eval
globalEval(readFileSync(resolve(__dirname, '../../../assets/javascripts/vendor/select2.min.js'), 'utf-8'));

const wait = (ms = 0) => new Promise((done) => { setTimeout(done, ms); });

// the search waits for the user to stop typing before it asks the server
const SEARCH_WAIT = 300;

let application;

beforeAll(() => {
  application = Application.start();
  application.register('additionals-select', AdditionalsSelectController);
  window.Stimulus = application;
});

afterAll(() => {
  application.stop();
  delete window.Stimulus;
});

afterEach(() => {
  document.body.innerHTML = '';
  vi.restoreAllMocks();
});

async function render(html) {
  document.body.innerHTML = html;
  await wait();
  return document.querySelector('select');
}

// The server answers searches with +entries+
function serverAnswers(entries) {
  return vi.spyOn(jQuery, 'ajax').mockImplementation(() => {
    const request = jQuery.Deferred().resolve(entries).promise();
    request.abort = () => {};
    return request;
  });
}

function open(select) {
  jQuery(select).select2('open');
}

function searchField(select) {
  const instance = jQuery(select).data('select2');
  return instance.selection.$search || instance.dropdown.$search;
}

function type(select, text) {
  searchField(select).val(text).trigger('input');
}

function entry(text) {
  return Array.from(document.querySelectorAll('.select2-results__option'))
    .find((option) => option.textContent.trim() === text);
}

// as a user does: the press of the button, then its release chooses
function choose(text, options = {}) {
  entry(text).dispatchEvent(new MouseEvent('mousedown', { bubbles: true, ...options }));
  jQuery(entry(text)).trigger(jQuery.Event('mouseup', options));
}

function press(element, key, which) {
  element.dispatchEvent(new KeyboardEvent('keydown', { key, keyCode: which, which, bubbles: true }));
}

// a click somewhere else on the page closes the list
function clickOutside() {
  document.body.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
  jQuery(document.body).trigger('mousedown');
}

function chosenTexts(select) {
  const container = jQuery(select).data('select2').$container[0];
  return Array.from(container.querySelectorAll('.select2-selection__choice'))
    .map((choice) => choice.getAttribute('title') || choice.textContent.replace('×', '').trim());
}

describe('AdditionalsSelectController', () => {
  describe('connect and disconnect', () => {
    it('turns the select into a select field of the library', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      expect(jQuery(select).data('select2')).toBeDefined();
    });

    it('removes the select field when the select leaves the page', async () => {
      const select = await render('<div><select data-controller="additionals-select"></select></div>');
      select.remove();
      await wait();

      expect(jQuery(select).data('select2')).toBeUndefined();
    });

    it('marks the field with a class of its own for the styles of plugins', async () => {
      const select = await render('<select data-controller="additionals-select"></select>');

      expect(jQuery(select).data('select2').$container[0].classList.contains('additionals-select-field')).toBe(true);
    });

    it('sets the field up again when a value changes', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');
      select.setAttribute('data-additionals-select-tags-value', 'true');
      await wait();

      expect(jQuery(select).data('select2').options.get('tags')).toBe(true);
    });

    it('waits for the library when it comes after the field', async () => {
      const { select2 } = jQuery.fn;
      delete jQuery.fn.select2;
      const select = await render('<select data-controller="additionals-select"></select>');
      jQuery.fn.select2 = select2;
      document.dispatchEvent(new Event('additionals-select:library-loaded'));

      expect(jQuery(select).data('select2')).toBeDefined();
    });

    it('leaves the select as it is without the library', async () => {
      const { select2 } = jQuery.fn;
      delete jQuery.fn.select2;
      try {
        const select = await render('<select data-controller="additionals-select"></select>');

        expect(select.classList.contains('select2-hidden-accessible')).toBe(false);
      } finally {
        jQuery.fn.select2 = select2;
      }
    });
  });

  describe('change', () => {
    // Stimulus actions and addEventListener never see changes the library
    // triggers through jQuery alone
    it('reaches jQuery handlers, native listeners and inline handlers exactly once', async () => {
      const select = await render(`
        <form id="form">
          <select data-controller="additionals-select" onchange="this.dataset.inline = Number(this.dataset.inline || 0) + 1">
            <option value="1">One</option><option value="2">Two</option>
          </select>
        </form>`);
      const native = vi.fn();
      const jquery = vi.fn();
      const delegated = vi.fn();
      select.addEventListener('change', native);
      jQuery(select).on('change', jquery);
      jQuery('#form').on('change', 'select', delegated);

      open(select);
      choose('Two');

      expect(select.value).toBe('2');
      expect([native.mock.calls.length, jquery.mock.calls.length, delegated.mock.calls.length, select.dataset.inline])
        .toEqual([1, 1, 1, '1']);
    });
  });

  describe('additionals-select:select', () => {
    it('tells the entry of the server without the fields of the library', async () => {
      serverAnswers([{ id: 7, text: 'Kurt', email: 'kurt@example.com' }]);
      const select = await render('<select data-controller="additionals-select" data-additionals-select-url-value="/search"></select>');
      const listener = vi.fn();
      select.addEventListener('additionals-select:select', listener);

      open(select);
      type(select, 'Ku');
      await wait(SEARCH_WAIT);
      choose('Kurt');

      expect(listener.mock.calls[0][0].detail.item).toEqual({ id: 7, text: 'Kurt', email: 'kurt@example.com' });
    });
  });

  describe('additionals-select:close', () => {
    it('is sent when the list closes', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');
      const listener = vi.fn();
      select.addEventListener('additionals-select:close', listener);

      open(select);
      jQuery(select).select2('close');

      expect(listener).toHaveBeenCalledTimes(1);
    });
  });

  describe('value key', () => {
    it('makes the property the value and leaves out entries without it', async () => {
      serverAnswers([{ id: 1, text: 'Kurt', email: 'kurt@example.com' }, { id: 2, text: 'No mail' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-value-key-value="email"></select>`);

      open(select);
      type(select, 'K');
      await wait(SEARCH_WAIT);

      expect(entry('No mail')).toBeUndefined();

      choose('Kurt');

      expect(jQuery(select).val()).toEqual(['kurt@example.com']);
    });
  });

  describe('scoped tags', () => {
    it('replaces a chosen tag of the same group and keeps the others', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-scoped-tags-value="true">
          <option value="prio::low" selected>prio::low</option>
          <option value="area::web" selected>area::web</option>
          <option value="plain" selected>plain</option>
          <option value="prio::high">prio::high</option>
        </select>`);

      open(select);
      choose('prio::high');

      expect(jQuery(select).val()).toEqual(['area::web', 'plain', 'prio::high']);
      expect(chosenTexts(select)).toEqual(['area::web', 'plain', 'prio::high']);
    });

    it('tells the listeners once, with the tag already replaced', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-scoped-tags-value="true">
          <option value="prio::low" selected>prio::low</option>
          <option value="prio::high">prio::high</option>
        </select>`);
      const seen = [];
      select.addEventListener('change', () => seen.push(jQuery(select).val()));

      open(select);
      choose('prio::high');

      expect(seen).toEqual([['prio::high']]);
    });
  });

  describe('free input', () => {
    it('takes the typed text when the field is left', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="known@example.com" selected>known@example.com</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      open(select);
      type(select, ' new@example.com ');
      jQuery(select).select2('close');

      expect(jQuery(select).val()).toEqual(['known@example.com', 'new@example.com']);
      expect(change).toHaveBeenCalledTimes(1);
    });

    it('takes only the chosen entry when the typed text found it', async () => {
      serverAnswers([{ id: 7, text: 'Kurt Albert', email: 'kurt@example.com' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-free-input-value="true" data-additionals-select-value-key-value="email">
        </select>`);

      open(select);
      type(select, 'Kurt');
      await wait(SEARCH_WAIT + 50);
      choose('Kurt Albert');

      expect(jQuery(select).val()).toEqual(['kurt@example.com']);
    });

    it('chooses the found entry with Enter, the typed text comes after it', async () => {
      serverAnswers([{ id: 7, text: 'Kurt Albert', email: 'kurt@example.com' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-free-input-value="true" data-additionals-select-value-key-value="email">
        </select>`);

      open(select);
      type(select, 'Kurt');
      await wait(SEARCH_WAIT + 50);
      press(searchField(select)[0], 'Enter', 13);

      expect(jQuery(select).val()).toEqual(['kurt@example.com']);
    });

    it('takes typed text only when it fits the pattern', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-free-input-pattern-value="@"></select>`);

      open(select);
      type(select, 'max');
      jQuery(select).select2('close');
      open(select);
      type(select, 'max@example.com');
      jQuery(select).select2('close');

      expect(jQuery(select).val()).toEqual(['max@example.com']);
    });

    it('ignores a pattern that is no regular expression', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-free-input-pattern-value="(@"></select>`);

      open(select);
      expect(() => type(select, 'max@example.com')).not.toThrow();
      jQuery(select).select2('close');

      expect(jQuery(select).val()).toEqual(['max@example.com']);
    });

    it('takes nothing when the field is left with Escape', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>`);

      open(select);
      type(select, 'new@example.com');
      press(searchField(select)[0], 'Escape', 27);

      expect(jQuery(select).val()).toEqual([]);
    });

    it('takes nothing when a chosen entry is removed from the list', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="a@example.com" selected>a@example.com</option>
          <option value="b@example.com" selected>b@example.com</option>
        </select>`);

      open(select);
      type(select, 'a@');
      choose('a@example.com');

      expect(jQuery(select).val()).toEqual(['b@example.com']);
    });

    it('keeps a chosen entry that the typed text found again', async () => {
      const select = await render(`
        <select data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value=""></option>
          <option value="kurt@example.com" selected>kurt@example.com</option>
        </select>`);

      open(select);
      type(select, 'kurt');
      choose('kurt@example.com');
      jQuery(select).select2('close');

      expect(jQuery(select).val()).toBe('kurt@example.com');
    });

    it('takes the typed text when the field is left with a click elsewhere', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>`);

      open(select);
      type(select, 'new@example.com');
      clickOutside();

      expect(jQuery(select).val()).toEqual(['new@example.com']);
    });

    it('takes typed text again after an Escape on the closed field and a choice with Ctrl', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="a@example.com">a@example.com</option>
        </select>`);

      press(searchField(select)[0], 'Escape', 27);
      open(select);
      choose('a@example.com', { ctrlKey: true });
      type(select, 'new@example.com');
      clickOutside();

      expect(jQuery(select).val()).toEqual(['a@example.com', 'new@example.com']);
    });

    it('does not take back an entry removed with Backspace', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="a@example.com" selected>a@example.com</option>
          <option value="b@example.com" selected>b@example.com</option>
        </select>`);

      open(select);
      press(searchField(select)[0], 'Backspace', 8);
      clickOutside();

      expect(jQuery(select).val()).toEqual(['a@example.com']);
    });

    it('replaces the tag of the same group with typed text too', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-scoped-tags-value="true">
          <option value="prio::low" selected>prio::low</option>
        </select>`);

      open(select);
      type(select, 'prio::high');
      clickOutside();

      expect(jQuery(select).val()).toEqual(['prio::high']);
    });

    it('takes nothing without typed text', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="known@example.com" selected>known@example.com</option>
        </select>`);

      open(select);
      jQuery(select).select2('close');

      expect(jQuery(select).val()).toEqual(['known@example.com']);
    });
  });

  describe('AdditionalsSelect', () => {
    it('refresh shows a value set from JavaScript and tells the listeners', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1">One</option><option value="2">Two</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      jQuery(select).val(['2']);
      AdditionalsSelect.refresh(select);

      expect(chosenTexts(select)).toEqual(['Two']);
      expect(change).toHaveBeenCalledTimes(1);
    });

    it('refresh does nothing without a field', () => {
      expect(() => AdditionalsSelect.refresh(null)).not.toThrow();
    });

    it('open opens the list of the field', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      AdditionalsSelect.open(select);

      expect(jQuery(select).data('select2').isOpen()).toBe(true);
    });

    it('destroy removes the select field of the library', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      AdditionalsSelect.destroy(select);

      expect(jQuery(select).data('select2')).toBeUndefined();
    });

    describe('menu', () => {
      const entries = [{ id: '1', text: 'First' }, { id: '2', text: 'Second' }];

      it('hands the chosen entry over and goes away', () => {
        document.body.innerHTML = '<button id="anchor">open</button>';
        const onSelect = vi.fn();
        const onClose = vi.fn();
        const select = AdditionalsSelect.menu({ anchor: document.getElementById('anchor'), entries, onSelect, onClose });

        choose('Second');

        expect(onSelect).toHaveBeenCalledWith({ id: '2', text: 'Second' });
        expect(onClose).not.toHaveBeenCalled();
        expect(select.isConnected).toBe(false);
        expect(document.querySelector('.select2-container')).toBeNull();
      });

      // a button near the right edge of the window opens the menu to its left
      it('stays inside the window', () => {
        document.body.innerHTML = '<button id="anchor">open</button>';
        const anchor = document.getElementById('anchor');
        anchor.getBoundingClientRect = () => ({ left: 900, right: 930, top: 20, bottom: 50 });
        const width = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'offsetWidth');
        Object.defineProperty(HTMLElement.prototype, 'offsetWidth', {
          configurable: true,
          get() { return this.classList.contains('additionals-select-field') ? 400 : 0; },
        });
        try {
          const select = AdditionalsSelect.menu({ anchor, entries });
          const container = jQuery(select).data('select2').$container[0];

          expect([container.style.left, container.style.top]).toEqual(['530px', '50px']);
        } finally {
          Object.defineProperty(HTMLElement.prototype, 'offsetWidth', width);
        }
      });

      it('goes away without a choice when it closes', () => {
        const onSelect = vi.fn();
        const onClose = vi.fn();
        const select = AdditionalsSelect.menu({ entries, onSelect, onClose });

        jQuery(select).select2('close');

        expect(onClose).toHaveBeenCalledTimes(1);
        expect(onSelect).not.toHaveBeenCalled();
        expect(select.isConnected).toBe(false);
      });
    });
  });
});

describe('renderers', () => {
  const html = (node) => (typeof node === 'string' ? node : node.outerHTML);
  const attack = '<img src=x onerror=alert(1)>';

  it('show names of the server as text', () => {
    expect(RENDERERS.name_with_icon.result({ id: 1, text: attack }).textContent).toBe(attack);
    expect(RENDERERS.avatar.result({ id: 1, text: attack, avatar: '' }).textContent).toBe(`\u00a0${attack}`);
    expect(html(RENDERERS.contact.result({ id: 1, text: attack, email: attack }))).not.toContain('<img');
  });

  it('show html of the server for icons and avatars', () => {
    expect(html(RENDERERS.name_with_icon.result({ id: 1, text: 'Bug', name_with_icon: '<svg class="icon"></svg> Bug' })))
      .toContain('<svg class="icon">');
    expect(html(RENDERERS.avatar.result({ id: 1, text: 'Kurt', avatar: '<img class="gravatar">' })))
      .toContain('<img class="gravatar">');
  });

  it('show a contact with its address once', () => {
    expect(RENDERERS.contact.selection({ text: 'Kurt', email: 'kurt@example.com' })).toBe('Kurt <kurt@example.com>');
    expect(RENDERERS.contact.selection({ text: 'kurt@example.com', email: 'kurt@example.com' })).toBe('kurt@example.com');
    expect(RENDERERS.contact.selection({ text: 'typed@example.com' })).toBe('typed@example.com');
  });

  it('show an icon from the sprite of the option', () => {
    const option = document.createElement('option');
    option.dataset.href = '/assets/icons-123.svg#icon--bug';
    const rendered = RENDERERS.icon.result({ id: 'bug', text: 'bug', element: option });

    expect(rendered.querySelector('use').getAttribute('href')).toBe('/assets/icons-123.svg#icon--bug');
    expect(rendered.textContent.trim()).toBe('bug');
  });

  it('show a color scheme with its colors', () => {
    window.Chart = { colorschemes: { brewer: { SetTwo8: ['#111111', '#222222'] } } };
    try {
      const rendered = RENDERERS.color_scheme.result({ id: 'brewer.SetTwo8', text: 'brewer.SetTwo' });

      expect(rendered.querySelectorAll('.colorscheme-swatch')).toHaveLength(2);
    } finally {
      delete window.Chart;
    }
  });
});

describe('tags', () => {
  it('build the group of a scoped tag', () => {
    expect([tagGroup('prio::high'), tagGroup('a::b::c'), tagGroup('plain')]).toEqual(['prio', 'a::b', '']);
  });

  it('remove only tags of the same group', () => {
    expect(withoutScopedSiblings(['prio::low', 'prio::high', 'prio', 'other::x'], 'prio::high'))
      .toEqual(['prio::high', 'prio', 'other::x']);
    expect(withoutScopedSiblings(['prio::low'], 'plain')).toEqual(['prio::low']);
  });

  it('create a tag from trimmed text without commas', () => {
    expect([createTag({ term: ' new ' }), createTag({ term: 'a,b' }), createTag({ term: ' ' })])
      .toEqual([{ id: 'new', text: 'new' }, null, null]);
  });

  it('take the value key of server entries', () => {
    expect(resultsWithValueKey([{ id: 1, email: 'a@b.c' }, { id: 2 }], 'email')).toEqual([{ id: 'a@b.c', email: 'a@b.c' }]);
    expect(resultsWithValueKey([{ id: 2 }], '')).toEqual([{ id: 2 }]);
  });
});
