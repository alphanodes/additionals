import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import jQuery from 'jquery';
import AdditionalsSelectController, {
  AdditionalsSelect, RENDERERS, tagGroup, withoutScopedSiblings, createTag, resultsWithValueKey,
} from '../../../assets/javascripts/controllers/additionals_select_controller.js';

import {
  loadSelectLibrary, hideSelectLibrary, serverAnswers, hasSelectField, fieldElement, openField, closeField, isOpen, pressField,
  typeInto, searchPlaceholder, entryTexts, entry, groupsOfList, isEntryDisabled, chooseEntry, pressKey, clickOutside,
  chosenTexts, shownElement, shownText, placeholderText, removeChosen, canClear, clearField,
  clickField, focusField, isDisabled, moveField, listTop, listParent, searchHasFocus, scrollList,
  setListHeight, listMessage, clearButton, removeButtonTitle, tabStartsFrom, announcement, listAllowsSeveral, suggestedTexts,
} from '../support/select_field.js';

// The controller is tested against the real library, as the pages use it: its
// job is the translation between our interface and the library, which a mock
// of the library could not show. The driver is the only part of the tests
// that knows the library.
loadSelectLibrary();

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

// The values of the select, as a form sends them
function values(select) {
  return Array.from(select.selectedOptions).map((option) => option.value);
}

describe('AdditionalsSelectController', () => {
  describe('connect and disconnect', () => {
    it('turns the select into a select field of the library', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      expect(hasSelectField(select)).toBe(true);
    });

    it('removes the select field when the select leaves the page', async () => {
      const select = await render('<div><select data-controller="additionals-select"></select></div>');
      select.remove();
      await wait();

      expect(hasSelectField(select)).toBe(false);
    });

    it('marks the field with a class of its own for the styles of plugins', async () => {
      const select = await render('<select data-controller="additionals-select"></select>');

      expect(fieldElement(select).classList.contains('additionals-select-field')).toBe(true);
    });

    // Core and plugins count the selects of a filter row by their class
    it('does not give the field the classes of the select', async () => {
      const select = await render('<select class="value own" data-controller="additionals-select"></select>');

      expect(['value', 'own'].map((name) => fieldElement(select).classList.contains(name))).toEqual([false, false]);
    });

    it('takes its width from the option, 90% without it', async () => {
      const wide = await render(`
        <select data-controller="additionals-select" data-additionals-select-width-value="300px"></select>
        <select id="plain" data-controller="additionals-select"></select>`);

      expect([fieldElement(wide).style.width, fieldElement(document.getElementById('plain')).style.width])
        .toEqual(['300px', '90%']);
    });

    // so it lies above dialogs and is not cut off by their borders
    it('hangs its list at the body', async () => {
      const select = await render('<div class="box"><select data-controller="additionals-select"></select></div>');

      expect(listParent(select)).toBe(document.body);
    });

    it('sets the field up again when a value changes, with its values', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);
      openField(select);
      chooseEntry('Two');
      select.setAttribute('data-additionals-select-tags-value', 'true');
      await wait();
      openField(select);
      typeInto(select, 'New tag');

      expect([entryTexts(), chosenTexts(select)]).toEqual([['New tag'], ['Two']]);
    });

    it('waits for the library when it comes after the field', async () => {
      const restoreLibrary = hideSelectLibrary();
      const select = await render('<select data-controller="additionals-select"></select>');
      restoreLibrary();
      document.dispatchEvent(new Event('additionals-select:library-loaded'));

      expect(hasSelectField(select)).toBe(true);
    });

    it('leaves the select as it is without the library', async () => {
      const restoreLibrary = hideSelectLibrary();
      try {
        const select = await render('<select data-controller="additionals-select"></select>');

        expect(hasSelectField(select)).toBe(false);
      } finally {
        restoreLibrary();
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

      openField(select);
      chooseEntry('Two');

      expect(select.value).toBe('2');
      expect([native.mock.calls.length, jquery.mock.calls.length, delegated.mock.calls.length, select.dataset.inline])
        .toEqual([1, 1, 1, '1']);
    });
  });

  describe('changes of the select', () => {
    it('follows the select when it is disabled and enabled again', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      select.disabled = true;
      await wait();
      const whenDisabled = isDisabled(select);
      select.disabled = false;
      await wait();

      expect([whenDisabled, isDisabled(select)]).toEqual([true, false]);
    });

    it('shows a value set from JavaScript that is told by change, without refresh', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);

      select.options[1].selected = true;
      select.dispatchEvent(new Event('change'));

      expect(chosenTexts(select)).toEqual(['Two']);
    });

    it('offers an option appended to the select, without refresh', async () => {
      const select = await render('<select multiple data-controller="additionals-select"><option value="1">One</option></select>');

      select.append(new Option('Two', '2'));
      await wait();
      openField(select);

      expect(entryTexts()).toEqual(['One', 'Two']);
    });

    it('follows a group of options removed from or appended to the select', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select"><optgroup label="Old"><option value="1">One</option></optgroup></select>`);

      select.querySelector('optgroup').remove();
      const group = document.createElement('optgroup');
      group.label = 'New';
      group.append(new Option('Two', '2'));
      select.append(group);
      await wait();
      openField(select);

      expect(entryTexts()).toEqual(['Two']);
    });

    it('no longer offers an option removed from the select', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1">One</option><option value="2">Two</option>
        </select>`);

      select.options[1].remove();
      await wait();
      openField(select);

      expect(entryTexts()).toEqual(['One']);
    });
  });

  describe('additionals-select:select', () => {
    it('tells the entry of the server without the fields of the library', async () => {
      serverAnswers([{ id: 7, text: 'Kurt', email: 'kurt@example.com' }]);
      const select = await render('<select data-controller="additionals-select" data-additionals-select-url-value="/search"></select>');
      const listener = vi.fn();
      select.addEventListener('additionals-select:select', listener);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      chooseEntry('Kurt');

      expect(listener.mock.calls[0][0].detail.item).toEqual({ id: 7, text: 'Kurt', email: 'kurt@example.com' });
    });
  });

  describe('additionals-select:select only for a choice of the user', () => {
    it('is not sent for values set from JavaScript', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);
      const listener = vi.fn();
      select.addEventListener('additionals-select:select', listener);

      select.options[1].selected = true;
      AdditionalsSelect.refresh(select);

      expect(listener).not.toHaveBeenCalled();
    });
  });

  describe('additionals-select:close', () => {
    it('is sent when the list closes', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');
      const listener = vi.fn();
      select.addEventListener('additionals-select:close', listener);

      openField(select);
      closeField(select);

      expect(listener).toHaveBeenCalledTimes(1);
    });
  });

  describe('value key', () => {
    it('makes the property the value and leaves out entries without it', async () => {
      serverAnswers([{ id: 1, text: 'Kurt', email: 'kurt@example.com' }, { id: 2, text: 'No mail' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-value-key-value="email"></select>`);

      openField(select);
      typeInto(select, 'K');
      await wait(SEARCH_WAIT);

      expect(entry('No mail')).toBeUndefined();

      chooseEntry('Kurt');

      expect(values(select)).toEqual(['kurt@example.com']);
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

      openField(select);
      chooseEntry('prio::high');

      expect(values(select)).toEqual(['area::web', 'plain', 'prio::high']);
      expect(chosenTexts(select)).toEqual(['area::web', 'plain', 'prio::high']);
    });

    it('tells the listeners once, with the tag already replaced', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-scoped-tags-value="true">
          <option value="prio::low" selected>prio::low</option>
          <option value="prio::high">prio::high</option>
        </select>`);
      const seen = [];
      select.addEventListener('change', () => seen.push(values(select)));

      openField(select);
      chooseEntry('prio::high');

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

      openField(select);
      typeInto(select, ' new@example.com ');
      closeField(select);

      expect(values(select)).toEqual(['known@example.com', 'new@example.com']);
      expect(change).toHaveBeenCalledTimes(1);
    });

    it('takes only the chosen entry when the typed text found it', async () => {
      serverAnswers([{ id: 7, text: 'Kurt Albert', email: 'kurt@example.com' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-free-input-value="true" data-additionals-select-value-key-value="email">
        </select>`);

      openField(select);
      typeInto(select, 'Kurt');
      await wait(SEARCH_WAIT + 50);
      chooseEntry('Kurt Albert');

      expect(values(select)).toEqual(['kurt@example.com']);
    });

    it('chooses the found entry with Enter, the typed text comes after it', async () => {
      serverAnswers([{ id: 7, text: 'Kurt Albert', email: 'kurt@example.com' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-url-value="/people"
                data-additionals-select-free-input-value="true" data-additionals-select-value-key-value="email">
        </select>`);

      openField(select);
      typeInto(select, 'Kurt');
      await wait(SEARCH_WAIT + 50);
      const offered = entryTexts();
      pressKey(select, 'Enter');

      expect([offered, values(select)]).toEqual([['Kurt Albert', 'Kurt'], ['kurt@example.com']]);
    });

    it('takes typed text only when it fits the pattern', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-free-input-pattern-value="@"></select>`);

      openField(select);
      typeInto(select, 'max');
      closeField(select);
      openField(select);
      typeInto(select, 'max@example.com');
      closeField(select);

      expect(values(select)).toEqual(['max@example.com']);
    });

    it('ignores a pattern that is no regular expression', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-free-input-pattern-value="(@"></select>`);

      openField(select);
      expect(() => typeInto(select, 'max@example.com')).not.toThrow();
      closeField(select);

      expect(values(select)).toEqual(['max@example.com']);
    });

    it('takes nothing when the field is left with Escape', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>`);

      openField(select);
      typeInto(select, 'new@example.com');
      pressKey(select, 'Escape');

      expect(values(select)).toEqual([]);
    });

    it('takes nothing when a chosen entry is removed from the list', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="a@example.com" selected>a@example.com</option>
          <option value="b@example.com" selected>b@example.com</option>
        </select>`);

      openField(select);
      typeInto(select, 'a@');
      chooseEntry('a@example.com');

      expect(values(select)).toEqual(['b@example.com']);
    });

    it('keeps a chosen entry that the typed text found again', async () => {
      const select = await render(`
        <select data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value=""></option>
          <option value="kurt@example.com" selected>kurt@example.com</option>
        </select>`);

      openField(select);
      typeInto(select, 'kurt');
      chooseEntry('kurt@example.com');
      closeField(select);

      expect(select.value).toBe('kurt@example.com');
    });

    it('takes the typed text when the field is left with a click elsewhere', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>`);

      openField(select);
      typeInto(select, 'new@example.com');
      clickOutside();

      expect(values(select)).toEqual(['new@example.com']);
    });

    // Going on to another select field leaves this one as a click elsewhere
    // does, the other field takes the focus from it when pressed
    it('takes the typed text when another select field is pressed', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>
        <select id="other" data-controller="additionals-select"><option value="1">One</option></select>`);

      openField(select);
      typeInto(select, 'new@example.com');
      pressField(document.getElementById('other'));

      expect(values(select)).toEqual(['new@example.com']);
    });

    it('takes the typed text when the field is left with Tab', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"></select>`);

      openField(select);
      typeInto(select, 'new@example.com');
      pressKey(select, 'Tab');

      expect([values(select), isOpen(select)]).toEqual([['new@example.com'], false]);
    });

    it('does not take back an entry removed with Backspace', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="a@example.com" selected>a@example.com</option>
          <option value="b@example.com" selected>b@example.com</option>
        </select>`);

      openField(select);
      pressKey(select, 'Backspace');
      clickOutside();

      expect(values(select)).toEqual(['a@example.com']);
    });

    it('replaces the tag of the same group with typed text too', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true"
                data-additionals-select-scoped-tags-value="true">
          <option value="prio::low" selected>prio::low</option>
        </select>`);

      openField(select);
      typeInto(select, 'prio::high');
      clickOutside();

      expect(values(select)).toEqual(['prio::high']);
    });

    it('takes nothing without typed text', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-free-input-value="true">
          <option value="known@example.com" selected>known@example.com</option>
        </select>`);

      openField(select);
      closeField(select);

      expect(values(select)).toEqual(['known@example.com']);
    });
  });

  describe('entries of the server', () => {
    const url = 'data-additionals-select-url-value="/search"';

    it('loads the list without a term when the field opens, then the list of each search', async () => {
      const server = serverAnswers((term) => [{ id: 1, text: `Found ${term}` }]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      await wait(SEARCH_WAIT);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);

      expect(server.terms).toEqual(['', 'Ku']);
      expect(entryTexts()).toEqual(['Found Ku']);
    });

    it('asks the server only from the minimal length of the search on', async () => {
      const server = serverAnswers([{ id: 1, text: 'Kurt' }]);
      const select = await render(`
        <select data-controller="additionals-select" ${url} data-additionals-select-min-input-length-value="2"></select>`);

      openField(select);
      typeInto(select, 'K');
      await wait(SEARCH_WAIT);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);

      expect(server.terms).toEqual(['Ku']);
    });

    // the server also finds by fields the entry does not show (login, address)
    it('asks the server again for the same search, its answer may have changed', async () => {
      const server = serverAnswers([{ id: 1, text: 'Kurt' }]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      closeField(select);
      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);

      expect(server.terms.filter((term) => term === 'Ku')).toHaveLength(2);
    });

    it('shows each entry of the answer, also without the search in its text', async () => {
      serverAnswers([{ id: 1, text: 'Kurt Albert' }, { id: 2, text: 'Anna' }]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'mail@example');
      await wait(SEARCH_WAIT);

      expect(entryTexts()).toEqual(['Kurt Albert', 'Anna']);
    });

    it('shows the groups of the answer, an entry in each of its groups', async () => {
      serverAnswers([
        { text: 'Watchers', children: [{ id: 1, text: 'Kurt' }, { id: 2, text: 'Anna' }] },
        { text: 'Active', children: [{ id: 1, text: 'Kurt' }, { id: 3, text: 'Locked', disabled: true }] },
      ]);
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'a');
      await wait(SEARCH_WAIT);

      expect(groupsOfList()).toEqual([
        { text: 'Watchers', entries: ['Kurt', 'Anna'] },
        { text: 'Active', entries: ['Kurt', 'Locked'] },
      ]);
      expect(isEntryDisabled('Locked')).toBe(true);

      chooseEntry('Locked');

      expect(values(select)).toEqual([]);
    });

    // "<< me >>" of a form field carries the id of the user, who is in a
    // group of the answer too: the entry stays on top, without the group
    it('keeps an entry on top that the answer repeats in a group', async () => {
      serverAnswers([
        { id: 3, text: '<< me >>' },
        { text: 'Involved', children: [{ id: 2, text: 'Anna' }, { id: 3, text: 'Berta' }] },
        { text: 'Active', children: [{ id: 3, text: 'Berta' }, { id: 4, text: 'Kurt' }] },
      ]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      await wait(SEARCH_WAIT);

      expect([entryTexts(), groupsOfList()]).toEqual([
        ['<< me >>', 'Anna', 'Kurt'],
        [{ text: 'Involved', entries: ['Anna'] }, { text: 'Active', entries: ['Kurt'] }],
      ]);
    });

    it('shows the answer to the last search when an earlier answer comes later', async () => {
      vi.spyOn(globalThis, 'fetch').mockImplementation((target) => {
        const term = new URL(target).searchParams.get('q') ?? '';
        const answer = [{ id: term || 'start', text: term ? `Found ${term}` : 'Start' }];
        return new Promise((done) => {
          setTimeout(() => done({ ok: true, json: () => Promise.resolve(answer) }), term ? 10 : 400);
        });
      });
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      await wait(SEARCH_WAIT);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT + 400);

      expect(entryTexts()).toEqual(['Found Ku']);
    });

    it('shows no answer to an earlier search, also below the minimal length and when opened again', async () => {
      serverAnswers((term) => [{ id: term, text: `Found ${term}` }]);
      const select = await render(`
        <select data-controller="additionals-select" ${url} data-additionals-select-min-input-length-value="2"></select>`);

      openField(select);
      typeInto(select, 'ab');
      await wait(SEARCH_WAIT);
      typeInto(select, 'a');
      const belowMinimum = entryTexts();
      closeField(select);
      openField(select);

      expect([belowMinimum, entryTexts()]).toEqual([[], []]);
    });

    it('keeps one option per chosen entry when the entry comes again in an answer', async () => {
      serverAnswers((term) => (term === 'Ku' ? [{ id: 7, text: 'Kurt' }] : [{ id: 7, text: 'Kurt' }, { id: 8, text: 'Anna' }]));
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      chooseEntry('Kurt');
      openField(select);
      typeInto(select, 'n');
      await wait(SEARCH_WAIT);
      chooseEntry('Anna');

      expect(select.querySelectorAll('option[value="7"]')).toHaveLength(1);
    });

    it('keeps one option per entry when it is removed and chosen again', async () => {
      serverAnswers([{ id: 7, text: 'Kurt' }]);
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      chooseEntry('Kurt');
      removeChosen(select, 'Kurt');
      openField(select);
      typeInto(select, 'Kur');
      await wait(SEARCH_WAIT);
      chooseEntry('Kurt');

      expect(select.querySelectorAll('option[value="7"]')).toHaveLength(1);
    });

    it('keeps the entries of the server when the select changes', async () => {
      serverAnswers([{ id: 7, text: 'Kurt' }, { id: 8, text: 'Anna' }]);
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'a');
      await wait(SEARCH_WAIT);
      select.append(new Option('Other', '9'));
      await wait();

      expect(entryTexts()).toEqual(['Kurt', 'Anna']);
    });

    it('shows no former start list when opened again', async () => {
      let answer = 'Start 1';
      serverAnswers(() => [{ id: answer, text: answer }]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      await wait(SEARCH_WAIT);
      closeField(select);
      answer = 'Start 2';
      openField(select);
      const atOnce = entryTexts();
      await wait(SEARCH_WAIT);

      expect([atOnce, entryTexts()]).toEqual([[], ['Start 2']]);
    });

    it('takes an entry with any data of the server', async () => {
      serverAnswers([{ id: 7, text: 'Kurt', 'foo-bar': 'x', 'two words': 'y' }]);
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      chooseEntry('Kurt');

      expect(values(select)).toEqual(['7']);
    });

    it('keeps what a chosen entry shows when the field is set up again', async () => {
      serverAnswers([{ id: 7, text: 'Kurt', email: 'kurt@example.com' }]);
      const select = await render(`
        <select multiple data-controller="additionals-select" ${url} data-additionals-select-renderer-value="contact"></select>`);

      openField(select);
      typeInto(select, 'Ku');
      await wait(SEARCH_WAIT);
      pressKey(select, 'Enter');
      select.setAttribute('data-additionals-select-placeholder-value', 'Add contacts');
      await wait();

      expect(chosenTexts(select)).toEqual(['Kurt <kurt@example.com>']);
    });

    it('asks the server nothing once the field is gone', async () => {
      const server = serverAnswers([]);
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      select.remove();
      await wait(SEARCH_WAIT);

      expect(server.terms).toEqual([]);
    });

    // e.g. a tag chosen before the answer to its search arrived
    it('stays closed when an answer comes after the list closed', async () => {
      serverAnswers([{ id: 1, text: 'Kurt' }]);
      const select = await render(`<select multiple data-controller="additionals-select" ${url}></select>`);

      openField(select);
      await wait();
      typeInto(select, 'Ku');
      closeField(select);
      await wait(SEARCH_WAIT);

      expect(isOpen(select)).toBe(false);
    });

    it('shows all entries of a long answer', async () => {
      serverAnswers(Array.from({ length: 60 }, (_, index) => ({ id: index + 1, text: `Entry ${index + 1}` })));
      const select = await render(`<select data-controller="additionals-select" ${url}></select>`);

      openField(select);
      typeInto(select, 'Entry');
      await wait(SEARCH_WAIT);

      expect(entryTexts()).toHaveLength(60);
    });
  });

  describe('list', () => {
    it('shows all options of a long select', async () => {
      const options = Array.from({ length: 60 }, (_, index) => `<option value="${index}">Option ${index}</option>`).join('');
      const select = await render(`<select data-controller="additionals-select">${options}</select>`);

      openField(select);

      expect(entryTexts()).toHaveLength(60);
    });

    it('chooses the entry reached with the arrow keys by Enter', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1">One</option><option value="2">Two</option><option value="3">Three</option>
        </select>`);

      openField(select);
      pressKey(select, 'ArrowDown');
      pressKey(select, 'ArrowDown');
      pressKey(select, 'ArrowUp');
      pressKey(select, 'Enter');

      expect(values(select)).toEqual(['2']);
    });

    // A field without any entry would open nothing and look broken. Fields
    // with entries of the server, new entries or entries of their own stay as
    // they are.
    it('tells that it has no entries only when it can offer none', async () => {
      const fields = {
        multiple: '<select multiple data-controller="additionals-select"></select>',
        single: '<select data-controller="additionals-select"><option value=""></option></select>',
        withEntries: '<select multiple data-controller="additionals-select"><option value="1">One</option></select>',
        tags: '<select multiple data-controller="additionals-select" data-additionals-select-tags-value="true"></select>',
        server: '<select multiple data-controller="additionals-select" data-additionals-select-url-value="/search"></select>',
      };
      const messages = {};
      for (const [name, html] of Object.entries(fields)) {
        const select = await render(html);
        openField(select);
        messages[name] = listMessage();
        closeField(select);
      }

      expect(messages).toEqual({ multiple: 'No results found', single: 'No results found', withEntries: null, tags: null, server: null });
    });

    it('keeps the order of its options when searching', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1">Pineapple</option><option value="2">Apple</option><option value="3">Pear</option>
        </select>`);

      openField(select);
      typeInto(select, 'apple');

      expect(entryTexts()).toEqual(['Pineapple', 'Apple']);
    });

    it('opens above the field where the window has no room below it', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value="1">One</option></select>
        <select id="high" data-controller="additionals-select"><option value="1">One</option></select>`);
      const high = document.getElementById('high');
      moveField(select, window.innerHeight - 60);
      setListHeight(select, 200);
      moveField(high, 100);
      setListHeight(high, 200);

      openField(select);
      openField(high);

      expect([listTop(select), listTop(high)]).toEqual([`${window.innerHeight - 260}px`, '100px']);
    });

    it('closes after a choice, also in a multiple field', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);

      openField(select);
      chooseEntry('One');

      expect(isOpen(select)).toBe(false);
    });

    it('keeps the value of a single field on Backspace in the empty search', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value="1" selected>One</option><option value="2">Two</option></select>`);

      openField(select);
      pressKey(select, 'Backspace');

      expect(select.value).toBe('1');
    });

    // the list hangs at the end of the page, Tab from its search would start
    // there instead of at the field
    it('leaves a single field with Tab from the field, not from its list', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);

      openField(select);

      expect([tabStartsFrom(select), isOpen(select), select.value]).toEqual(['field', false, '1']);
    });

    it('closes with Escape and with a click elsewhere, without a choice', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value="1">One</option><option value="2">Two</option></select>`);

      openField(select);
      pressKey(select, 'Escape');
      const afterEscape = isOpen(select);
      openField(select);
      clickOutside();

      expect([afterEscape, isOpen(select), select.value]).toEqual([false, false, '1']);
    });

    it('opens with a click on the field, not when it only gets the focus', async () => {
      const server = serverAnswers([]);
      const select = await render('<select data-controller="additionals-select" data-additionals-select-url-value="/search"></select>');

      focusField(select);
      await wait(SEARCH_WAIT);
      const afterFocus = [isOpen(select), server.terms.length];
      clickField(select);

      expect([afterFocus, isOpen(select)]).toEqual([[false, 0], true]);
    });

    // Pressing the field takes the focus from a field elsewhere, as for a
    // select of the browser: the library keeps it there (preventDefault), and
    // Firefox puts it back into a field showing its input history, which
    // closes the list. A disabled field leaves the focus where it is, and so
    // does the open field pressed again: its own search keeps it.
    it('takes the focus from a field elsewhere when pressed, unless disabled or its own', async () => {
      const select = await render(`
        <input id="name" type="text">
        <select data-controller="additionals-select"><option value="1">One</option></select>
        <select id="locked" disabled data-controller="additionals-select"><option value="1">One</option></select>`);
      const name = document.getElementById('name');
      const nameKeepsFocus = (field) => {
        name.focus();
        pressField(field);
        return document.activeElement === name;
      };
      const kept = [nameKeepsFocus(select), nameKeepsFocus(document.getElementById('locked'))];
      openField(select);
      pressField(select);

      expect([...kept, searchHasFocus(select), isOpen(select)]).toEqual([false, true, true, true]);
    });

    it('opens a field with entries of the server with the arrow down', async () => {
      serverAnswers([{ id: 1, text: 'Kurt' }]);
      const select = await render('<select data-controller="additionals-select" data-additionals-select-url-value="/search"></select>');

      focusField(select);
      pressKey(select, 'ArrowDown');

      expect(isOpen(select)).toBe(true);
    });

    it('opens with Enter on the closed field instead of submitting the form', async () => {
      const select = await render(`
        <form><select multiple data-controller="additionals-select"><option value="1">One</option></select></form>`);

      openField(select);
      closeField(select);
      const kept = pressKey(select, 'Enter');

      expect([kept, isOpen(select)]).toEqual([true, true]);
    });

    it('follows the field when a container around it scrolls', async () => {
      const select = await render(`
        <div id="box" style="overflow: auto"><select data-controller="additionals-select"><option value="1">One</option></select></div>`);
      moveField(select, 100);
      openField(select);
      const before = listTop(select);

      moveField(select, 40);
      document.getElementById('box').dispatchEvent(new Event('scroll'));

      expect([before, listTop(select)]).toEqual(['100px', '40px']);
    });

    it('stays where it is when the list itself scrolls', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');
      moveField(select, 100);
      openField(select);

      moveField(select, 40);
      scrollList(select);

      expect(listTop(select)).toBe('100px');
    });

    // the placeholder stands for the empty option, allow_clear goes back to it
    it('offers no empty option', async () => {
      const select = await render(`
        <select data-controller="additionals-select">
          <option value=""></option><option value="1" selected>One</option>
        </select>`);

      openField(select);

      expect(entryTexts()).toEqual(['One']);
    });
  });

  describe('placeholder', () => {
    it('is shown by an empty field', async () => {
      const single = await render(`
        <select data-controller="additionals-select" data-additionals-select-placeholder-value="Choose a user">
          <option value=""></option><option value="1">One</option>
        </select>
        <select id="multiple" multiple data-controller="additionals-select"
                data-additionals-select-placeholder-value="Choose users"><option value="1">One</option></select>`);

      expect([placeholderText(single), placeholderText(document.getElementById('multiple'))])
        .toEqual(['Choose a user', 'Choose users']);
    });

  });

  // the texts of the page language, the library has English ones of its own
  describe('labels', () => {
    beforeAll(() => {
      window.ADDITIONALS_SELECT_LABELS = { search: 'Suche', noResults: 'Nichts', clear: 'Leeren', remove: 'Entfernen' };
    });

    afterAll(() => { delete window.ADDITIONALS_SELECT_LABELS; });

    it('label the search of the list and tell that nothing was found', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      openField(select);
      typeInto(select, 'xyz');

      expect([searchPlaceholder(select), listMessage()]).toEqual(['Suche', 'Nichts']);
    });

    it('label the buttons that empty the field and remove an entry', async () => {
      const single = await render(`
        <select data-controller="additionals-select" data-additionals-select-allow-clear-value="true">
          <option value=""></option><option value="1" selected>One</option>
        </select>
        <select id="multiple" multiple data-controller="additionals-select"><option value="1" selected>One</option></select>`);

      expect([clearButton(single), removeButtonTitle(document.getElementById('multiple'), 'One')])
        .toEqual([{ title: 'Leeren', tabStop: false }, 'Entfernen']);
    });

    it('tell nothing was found only while no new entry is offered', async () => {
      const select = await render('<select multiple data-controller="additionals-select" data-additionals-select-tags-value="true"></select>');

      openField(select);
      typeInto(select, 'urgent');

      expect([entryTexts(), listMessage()]).toEqual([['urgent'], null]);
    });
  });

  describe('screen readers', () => {
    it('hear the name of a single field and the marked entry in its search', async () => {
      const select = await render(`
        <label for="assignee">Assignee</label>
        <select id="assignee" data-controller="additionals-select">
          <option value="1" selected>One</option><option value="2">Two</option>
        </select>`);

      openField(select);
      pressKey(select, 'ArrowDown');

      expect(announcement()).toEqual({ role: 'combobox', name: 'Assignee', marked: 'Two' });
    });

    it('learn that the list of a multiple field takes several entries', async () => {
      const multiple = await render('<select multiple data-controller="additionals-select"><option value="1">One</option></select>');
      document.body.insertAdjacentHTML('beforeend', '<select id="single" data-controller="additionals-select"><option value="1">One</option></select>');
      await wait();

      expect([listAllowsSeveral(multiple), listAllowsSeveral(document.getElementById('single'))]).toEqual([true, false]);
    });
  });

  describe('allow clear', () => {
    it('empties a single field and tells the listeners once', async () => {
      const select = await render(`
        <select data-controller="additionals-select" data-additionals-select-allow-clear-value="true"
                data-additionals-select-placeholder-value="None">
          <option value=""></option><option value="1" selected>One</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      expect(canClear(select)).toBe(true);

      clearField(select);

      expect([select.value, shownText(select), change.mock.calls.length]).toEqual(['', 'None', 1]);
    });

    it('is not offered without the option', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value=""></option><option value="1" selected>One</option></select>`);

      expect(canClear(select)).toBe(false);
    });

    it('empties a single field with Backspace or Delete while its list is closed', async () => {
      const html = `
        <select data-controller="additionals-select" data-additionals-select-allow-clear-value="true">
          <option value=""></option><option value="1" selected>One</option>
        </select>`;
      const emptied = [];
      for (const key of ['Backspace', 'Delete']) {
        const select = await render(html);
        const change = vi.fn();
        select.addEventListener('change', change);
        const kept = pressKey(select, key);
        emptied.push([key, select.value, change.mock.calls.length, kept]);
      }

      expect(emptied).toEqual([['Backspace', '', 1, true], ['Delete', '', 1, true]]);
    });

    it('keeps a single field without the option on Delete', async () => {
      const select = await render(`
        <select data-controller="additionals-select"><option value=""></option><option value="1" selected>One</option></select>`);

      pressKey(select, 'Delete');

      expect(select.value).toBe('1');
    });
  });

  // "<< me >>" chosen for a new filter (as core does) is a suggestion: the
  // first entry the user chooses replaces it, later ones are added
  describe('suggestion', () => {
    it('is replaced by the first entry the user chooses', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-suggestion-value="me">
          <option value="me" selected>&lt;&lt; me &gt;&gt;</option><option value="2">Two</option><option value="3">Three</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      const suggested = suggestedTexts(select);
      openField(select);
      chooseEntry('Two');
      const first = values(select);
      openField(select);
      chooseEntry('<< me >>');

      expect([suggested, first, values(select), suggestedTexts(select), change.mock.calls.length])
        .toEqual([['<< me >>'], ['2'], ['2', 'me'], [], 2]);
    });

    // choosing the suggested entry takes it, it does not remove it as a
    // second choice of a chosen entry would
    it('becomes a value when the user chooses it', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-suggestion-value="me">
          <option value="me" selected>&lt;&lt; me &gt;&gt;</option><option value="2">Two</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      openField(select);
      chooseEntry('<< me >>');

      expect([values(select), chosenTexts(select), suggestedTexts(select), change.mock.calls.length])
        .toEqual([['me'], ['<< me >>'], [], 0]);
    });
  });

  describe('chosen entries', () => {
    it('removes an entry with its button and tells the listeners once', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1" selected>One</option><option value="2" selected>Two</option>
        </select>`);
      const change = vi.fn();
      select.addEventListener('change', change);

      removeChosen(select, 'One');

      expect([values(select), chosenTexts(select), change.mock.calls.length]).toEqual([['2'], ['Two'], 1]);
    });

    it('forgets entries marked with the arrow keys when the field is clicked', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1" selected>One</option><option value="2" selected>Two</option><option value="3" selected>Three</option>
        </select>`);

      openField(select);
      closeField(select);
      pressKey(select, 'ArrowLeft', { shiftKey: true });
      pressKey(select, 'ArrowLeft', { shiftKey: true });
      clickField(select);
      pressKey(select, 'Backspace');

      expect(values(select)).toEqual(['1', '2']);
    });

    it('removes the last entry with Backspace in the empty search', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1" selected>One</option><option value="2" selected>Two</option>
        </select>`);

      openField(select);
      pressKey(select, 'Backspace');

      expect(values(select)).toEqual(['1']);
    });

    it('shows the icon of the chosen option', async () => {
      const select = await render(`
        <select data-controller="additionals-select" data-additionals-select-renderer-value="icon">
          <option value="bug" data-href="/assets/icons-1.svg#icon--bug" selected>bug</option>
        </select>`);

      expect(shownElement(select).querySelector('.additionals-select-icon use').getAttribute('href'))
        .toBe('/assets/icons-1.svg#icon--bug');
    });
  });

  describe('tags', () => {
    const tagField = '<select multiple data-controller="additionals-select" data-additionals-select-tags-value="true"></select>';

    it('offers typed text as a new tag', async () => {
      const select = await render(tagField);

      openField(select);
      typeInto(select, 'urgent');
      chooseEntry('urgent');

      expect(values(select)).toEqual(['urgent']);
    });

    it('offers a tag that exists once, not as new tag too', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select" data-additionals-select-tags-value="true">
          <option value="urgent">urgent</option>
        </select>`);

      openField(select);
      typeInto(select, 'urgent');

      expect(entryTexts()).toEqual(['urgent']);
    });

    it('takes the text before a comma as a tag of its own', async () => {
      const select = await render(tagField);

      openField(select);
      typeInto(select, 'alpha,beta,');

      expect(chosenTexts(select)).toEqual(['alpha', 'beta']);
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

      select.options[1].selected = true;
      AdditionalsSelect.refresh(select);

      expect(chosenTexts(select)).toEqual(['Two']);
      expect(change).toHaveBeenCalledTimes(1);
    });

    it('refresh shows an option appended from JavaScript as chosen value', async () => {
      const multiple = await render(`
        <select multiple data-controller="additionals-select"><option value="1" selected>One</option></select>
        <select id="single" data-controller="additionals-select"><option value="1">One</option></select>`);
      const single = document.getElementById('single');

      multiple.append(new Option('Two', '2', true, true));
      AdditionalsSelect.refresh(multiple);
      single.append(new Option('Two', '2', true, true));
      AdditionalsSelect.refresh(single);

      expect(chosenTexts(multiple)).toEqual(['One', 'Two']);
      expect(shownText(single)).toBe('Two');
    });

    it('stays empty when a value without an option is set from JavaScript', async () => {
      const tellings = [
        (select) => AdditionalsSelect.refresh(select),
        (select) => select.dispatchEvent(new Event('change', { bubbles: true })),
      ];
      const results = [];
      for (const tell of tellings) {
        const select = await render(`
          <select data-controller="additionals-select">
            <option value=""></option><option value="1">First</option><option value="2" selected>Second</option>
          </select>`);

        select.value = '99';
        tell(select);
        results.push([select.value, chosenTexts(select)]);
      }

      expect(results).toEqual([['', []], ['', []]]);
    });

    it('refresh does nothing without a field', () => {
      expect(() => AdditionalsSelect.refresh(null)).not.toThrow();
    });

    it('open opens the list of the field', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      AdditionalsSelect.open(select);
      await wait();

      expect([isOpen(select), searchHasFocus(select)]).toEqual([true, true]);
    });

    it('destroy removes the select field of the library', async () => {
      const select = await render('<select data-controller="additionals-select"><option value="1">One</option></select>');

      AdditionalsSelect.destroy(select);

      expect(hasSelectField(select)).toBe(false);
    });

    it('destroy keeps the options and values of the select', async () => {
      const select = await render(`
        <select multiple data-controller="additionals-select">
          <option value="1">One</option><option value="2">Two</option>
        </select>`);
      select.append(new Option('Three', '3'));
      AdditionalsSelect.refresh(select);
      openField(select);
      chooseEntry('Three');

      AdditionalsSelect.destroy(select);

      expect([Array.from(select.options).map((option) => option.text), values(select)])
        .toEqual([['One', 'Two', 'Three'], ['3']]);
    });

    describe('menu', () => {
      const entries = [{ id: '1', text: 'First' }, { id: '2', text: 'Second' }];

      it('hands the chosen entry over and goes away', () => {
        document.body.innerHTML = '<button id="anchor">open</button>';
        const onSelect = vi.fn();
        const onClose = vi.fn();
        const select = AdditionalsSelect.menu({ anchor: document.getElementById('anchor'), entries, onSelect, onClose });

        chooseEntry('Second');

        expect(onSelect).toHaveBeenCalledWith({ id: '2', text: 'Second' });
        expect(onClose).not.toHaveBeenCalled();
        expect(select.isConnected).toBe(false);
        expect(document.querySelector('.additionals-select-field')).toBeNull();
      });

      it('chooses with the arrow keys and Enter', () => {
        const onSelect = vi.fn();
        const select = AdditionalsSelect.menu({ entries, onSelect });

        pressKey(select, 'ArrowDown');
        pressKey(select, 'Enter');

        expect(onSelect).toHaveBeenCalledWith({ id: '2', text: 'Second' });
      });

      it('gives the focus back after Escape', () => {
        document.body.innerHTML = '<button id="anchor">open</button>';
        const anchor = document.getElementById('anchor');
        anchor.focus();
        const select = AdditionalsSelect.menu({ anchor, entries });
        document.activeElement.blur();

        pressKey(select, 'Escape');

        expect(document.activeElement).toBe(anchor);
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
          const container = fieldElement(select);

          expect([container.style.left, container.style.top]).toEqual(['530px', '50px']);
        } finally {
          Object.defineProperty(HTMLElement.prototype, 'offsetWidth', width);
        }
      });

      it('goes away without a choice with Escape or a click elsewhere', () => {
        const onClose = vi.fn();
        const withEscape = AdditionalsSelect.menu({ entries, onClose });
        pressKey(withEscape, 'Escape');
        const withClick = AdditionalsSelect.menu({ entries, onClose });
        clickOutside();

        expect([withEscape.isConnected, withClick.isConnected, onClose.mock.calls.length]).toEqual([false, false, 2]);
      });

      it('goes away without a choice when it closes', () => {
        const onSelect = vi.fn();
        const onClose = vi.fn();
        const select = AdditionalsSelect.menu({ entries, onSelect, onClose });

        closeField(select);

        expect(onClose).toHaveBeenCalledTimes(1);
        expect(onSelect).not.toHaveBeenCalled();
        expect(select.isConnected).toBe(false);
      });
    });
  });
});

describe('renderers', () => {
  afterEach(() => { delete window.additionalsSelectRenderers; });

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

  // Plugins register renderers of their own, e.g. tags with their colors;
  // the field looks them up when it is set up. A chosen entry without
  // selection shows its text, a built-in renderer is not replaced, and a name
  // nobody knows (also one every object inherits) shows text.
  it('take renderers other plugins register', async () => {
    const mark = (item) => Object.assign(document.createElement('mark'), { textContent: item.text });
    window.additionalsSelectRenderers = { mark: { result: mark, selection: mark }, listed: { result: mark }, icon: { result: mark, selection: mark } };
    const field = (id, renderer) => `
      <select id="${id}" multiple data-controller="additionals-select" data-additionals-select-renderer-value="${renderer}">
        <option value="1" selected>One</option><option value="2">Two</option>
      </select>`;
    const select = await render(['mark', 'listed', 'icon', 'nobody', 'constructor'].map((name) => field(name, name)).join(''));
    openField(select);
    const marks = (node) => Array.from(node.querySelectorAll('mark'), (element) => element.textContent);
    const listMarks = marks(document.querySelector('.additionals-select-dropdown'));
    closeField(select);
    const inherited = document.getElementById('constructor');
    openField(inherited);
    const inheritedList = entryTexts();
    closeField(inherited);
    const chosen = (id) => {
      const element = fieldElement(document.getElementById(id));
      return [marks(element), element.querySelector('.item').textContent.replace('×', '').trim()];
    };

    expect([listMarks, inheritedList, chosen('mark'), chosen('listed'), chosen('icon'), chosen('nobody'), chosen('constructor')])
      .toEqual([['One', 'Two'], ['One', 'Two'], [['One'], 'One'], [[], 'One'], [[], 'One'], [[], 'One'], [[], 'One']]);
  });

  it('show a contact with its address once', () => {
    expect(RENDERERS.contact.selection({ text: 'Kurt', email: 'kurt@example.com' })).toBe('Kurt <kurt@example.com>');
    expect(RENDERERS.contact.selection({ text: 'kurt@example.com', email: 'kurt@example.com' })).toBe('kurt@example.com');
    expect(RENDERERS.contact.selection({ text: 'typed@example.com' })).toBe('typed@example.com');
  });

  it('show an icon from the sprite of the option', () => {
    const rendered = RENDERERS.icon.result({ id: 'bug', text: 'bug', href: '/assets/icons-123.svg#icon--bug' });

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
