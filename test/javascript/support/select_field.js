// Test driver for select fields: works a field the way a user does (open,
// type, choose, keys, click elsewhere) and reads what the user sees (entries,
// chosen values, placeholder). It is the only place of the JavaScript tests
// that knows the library behind the fields, the tests of behavior speak to
// this driver and to the contract of docs/select-fields.md.
import { vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const KEY_CODES = { Enter: 13, Escape: 27, Backspace: 8, Tab: 9, ArrowDown: 40, ArrowUp: 38, ArrowLeft: 37 };

// Loads the library into the page, as the pages of Redmine do
export function loadSelectLibrary() {
  // jsdom takes the focus from the page when no element has it, a browser
  // keeps it; the library ignores leaving a field while the page has no focus
  document.hasFocus = () => true;
  const globalEval = eval; // eslint-disable-line no-eval
  globalEval(readFileSync(resolve(__dirname, '../../../assets/javascripts/vendor/tom-select.complete.min.js'), 'utf-8'));
}

// Takes the library from the page, as on pages that load it later; the
// returned function brings it back
export function hideSelectLibrary() {
  const library = window.TomSelect;
  delete window.TomSelect;
  return () => { window.TomSelect = library; };
}

// The server answers each search with +answer+, or with what +answer+
// returns for the search term. The searches are collected in +terms+, an empty
// string for a request without term.
export function serverAnswers(answer) {
  const terms = [];
  vi.spyOn(globalThis, 'fetch').mockImplementation((url) => {
    const term = new URL(url).searchParams.get('q') ?? '';
    terms.push(term);
    const entries = typeof answer === 'function' ? answer(term) : answer;
    return Promise.resolve({ ok: true, json: () => Promise.resolve(entries) });
  });
  return { terms };
}

function instanceOf(select) {
  return select.tomselect;
}

// The select is turned into a select field
export function hasSelectField(select) {
  return instanceOf(select) !== undefined;
}

// The element of the select field that is shown in place of the select
export function fieldElement(select) {
  return instanceOf(select).wrapper;
}

// The library takes the focus a moment after it opens, as a user's click
// would have it at once
function takeFocus(instance) {
  instance.ignoreFocus = false;
  instance.onFocus();
}

export function openField(select) {
  const instance = instanceOf(select);
  instance.open();
  takeFocus(instance);
}

// Closes the list from a program, not by a user
export function closeField(select) {
  instanceOf(select).close();
}

export function isOpen(select) {
  return instanceOf(select).isOpen;
}

// A click on the field, as a user opens or closes its list
export function clickField(select) {
  const { control } = instanceOf(select);
  ['mousedown', 'mouseup', 'click'].forEach((type) => {
    control.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true }));
  });
}

// The field gets the focus without a click, e.g. with Tab from the field
// before it
export function focusField(select) {
  const instance = instanceOf(select);
  (instance.settings.mode === 'multi' ? instance.control_input : instance.focus_node).focus();
}

export function isDisabled(select) {
  return instanceOf(select).isDisabled;
}

// The field moves to +top+ on the page (e.g. its container scrolled), the
// position of its open list is read with listTop
export function moveField(select, top) {
  instanceOf(select).control.getBoundingClientRect = () => ({ top, bottom: top + 25, left: 10, right: 210, width: 200, height: 25 });
}

export function listTop(select) {
  return instanceOf(select).dropdown.style.top;
}

// The user scrolls inside the open list
export function scrollList(select) {
  instanceOf(select).dropdown_content.dispatchEvent(new Event('scroll'));
}

// The element the list of the field hangs at
export function listParent(select) {
  return instanceOf(select).dropdown.parentElement;
}

// The search of the field has the focus, the user types into it at once
export function searchHasFocus(select) {
  return document.activeElement === searchField(select);
}

function searchField(select) {
  return instanceOf(select).control_input;
}

// The key code of a keydown names the key, not the character: letters as
// capitals, digits as such; other keys differ by keyboard and get none
function keyDownCode(character) {
  return /^[a-z0-9]$/i.test(character) ? character.toUpperCase().charCodeAt(0) : 0;
}

// Types +text+ into the search of the field, key by key: a key the field
// keeps (keydown or keypress) types nothing
export function typeInto(select, text) {
  const search = searchField(select);
  search.value = '';
  Array.from(text).forEach((character) => {
    const key = (type, code) => new KeyboardEvent(type, { key: character, keyCode: code, which: code, bubbles: true, cancelable: true });
    if (!search.dispatchEvent(key('keydown', keyDownCode(character))) ||
        !search.dispatchEvent(key('keypress', character.charCodeAt(0)))) { return; }

    search.value += character;
    search.dispatchEvent(new Event('input', { bubbles: true }));
  });
}

// The placeholder of the search field, a single field has its own in the list
export function searchPlaceholder(select) {
  return searchField(select).getAttribute('placeholder');
}

function openDropdowns() {
  return Array.from(document.querySelectorAll('.ts-dropdown')).filter((dropdown) => dropdown.style.display !== 'none');
}

// Entries of the open list, without headings of groups
function listEntries() {
  return openDropdowns().flatMap((dropdown) => Array.from(dropdown.querySelectorAll('.option, .create')));
}

export function entryTexts() {
  return listEntries().map((option) => option.textContent.trim());
}

export function entry(text) {
  return listEntries().find((option) => option.textContent.trim() === text);
}

// Headings of the groups in the open list, each with the texts of its entries
export function groupsOfList() {
  return openDropdowns().flatMap((dropdown) => Array.from(dropdown.querySelectorAll('.optgroup')).map((group) => ({
    text: group.querySelector('.optgroup-header').textContent.trim(),
    entries: Array.from(group.querySelectorAll('.option')).map((option) => option.textContent.trim()),
  })));
}

export function isEntryDisabled(text) {
  return entry(text).getAttribute('aria-disabled') === 'true';
}

// As a user does: the press of the button, its release and the click
export function chooseEntry(text, options = {}) {
  const option = entry(text);
  ['mousedown', 'mouseup', 'click'].forEach((type) => {
    option.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, ...options }));
  });
}

// A key pressed in the field: in its search while it has one in sight, else
// on the field. Tab leaves the field, as the browser does. Returns whether
// the field kept the key from the page (e.g. Enter from submitting the form).
// +modifiers+ like { shiftKey: true } are held down with the key.
export function pressKey(select, key, modifiers = {}) {
  const instance = instanceOf(select);
  const target = instance.isOpen || instance.settings.mode === 'multi' ? instance.control_input : instance.focus_node;
  const which = KEY_CODES[key];
  const event = new KeyboardEvent('keydown', { key, keyCode: which, which, bubbles: true, cancelable: true, ...modifiers });
  const passed = target.dispatchEvent(event);
  if (passed && key === 'Tab') { instance.blur(); }
  return !passed;
}

// A click somewhere else on the page
export function clickOutside() {
  document.body.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
}

function chosenItems(select) {
  return Array.from(fieldElement(select).querySelectorAll('.ts-control > .item'));
}

function itemText(item) {
  const copy = item.cloneNode(true);
  copy.querySelector('.remove')?.remove();
  return copy.textContent.trim();
}

// Texts of the chosen entries of a multiple field
export function chosenTexts(select) {
  return chosenItems(select).map(itemText);
}

// What a single field shows: the chosen entry or its placeholder
export function shownElement(select) {
  return chosenItems(select)[0] || fieldElement(select).querySelector('.items-placeholder');
}

export function shownText(select) {
  const shown = shownElement(select);
  return shown.classList.contains('item') ? itemText(shown) : shown.getAttribute('placeholder');
}

// The placeholder of an empty field
export function placeholderText(select) {
  const instance = instanceOf(select);
  const input = instance.settings.mode === 'multi' ? instance.control_input : fieldElement(select).querySelector('.items-placeholder');
  return input?.getAttribute('placeholder') ?? null;
}

// Removes the chosen entry +text+ of a multiple field with its button
export function removeChosen(select, text) {
  const item = chosenItems(select).find((element) => itemText(element) === text);
  item.querySelector('.remove').dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
}

// The field offers to clear its value
export function canClear(select) {
  return fieldElement(select).querySelector('.clear-button') !== null;
}

export function clearField(select) {
  fieldElement(select).querySelector('.clear-button').dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
}
