// Test driver for select fields: works a field the way a user does (open,
// type, choose, keys, click elsewhere) and reads what the user sees (entries,
// chosen values, placeholder). It is the only place of the JavaScript tests
// that knows the library behind the fields, the tests of behavior speak to
// this driver and to the contract of docs/select-fields.md.
import { vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import jQuery from 'jquery';

const KEY_CODES = { Enter: 13, Escape: 27, Backspace: 8, Tab: 9, ArrowDown: 40, ArrowUp: 38 };

// Loads the library into the page, as the pages of Redmine do
export function loadSelectLibrary() {
  globalThis.jQuery = jQuery;
  globalThis.$ = jQuery;
  const globalEval = eval; // eslint-disable-line no-eval
  globalEval(readFileSync(resolve(__dirname, '../../../assets/javascripts/vendor/select2.min.js'), 'utf-8'));
}

// Takes the library from the page, as on pages that load it later; the
// returned function brings it back
export function hideSelectLibrary() {
  const { select2 } = jQuery.fn;
  delete jQuery.fn.select2;
  return () => { jQuery.fn.select2 = select2; };
}

// The server answers each search with +answer+, or with what +answer+
// returns for the search term. The searches are collected in +terms+, an empty
// string for a request without term.
export function serverAnswers(answer) {
  const terms = [];
  vi.spyOn(jQuery, 'ajax').mockImplementation((options) => {
    const term = options.data?.q ?? '';
    terms.push(term);
    const entries = typeof answer === 'function' ? answer(term) : answer;
    const request = jQuery.Deferred().resolve(entries).promise();
    request.abort = () => {};
    return request;
  });
  return { terms };
}

function instanceOf(select) {
  return jQuery(select).data('select2');
}

// The select is turned into a select field
export function hasSelectField(select) {
  return instanceOf(select) !== undefined;
}

// The element of the select field that is shown in place of the select
export function fieldElement(select) {
  return instanceOf(select).$container[0];
}

export function openField(select) {
  jQuery(select).select2('open');
}

// Closes the list from a program, not by a user
export function closeField(select) {
  jQuery(select).select2('close');
}

export function isOpen(select) {
  return instanceOf(select).isOpen();
}

function searchField(select) {
  const instance = instanceOf(select);
  return (instance.selection.$search || instance.dropdown.$search)[0];
}

// Types +text+ into the search of the field
export function typeInto(select, text) {
  jQuery(searchField(select)).val(text).trigger('input');
}

// The placeholder of the search field, a single field has its own in the list
export function searchPlaceholder(select) {
  const instance = instanceOf(select);
  const field = instance.dropdown.$search || instance.selection.$search;
  return field[0].getAttribute('placeholder');
}

// Entries of the open list, without headings of groups
function listEntries() {
  return Array.from(document.querySelectorAll('.select2-results__option[role="option"], .select2-results__option[role="treeitem"]'));
}

export function entryTexts() {
  return listEntries().map((option) => option.textContent.trim());
}

export function entry(text) {
  return listEntries().find((option) => option.textContent.trim() === text);
}

// Headings of the groups in the open list, each with the texts of its entries
export function groupsOfList() {
  return Array.from(document.querySelectorAll('.select2-results__option[role="group"]')).map((group) => ({
    text: group.querySelector('.select2-results__group').textContent.trim(),
    entries: Array.from(group.querySelectorAll('.select2-results__option')).map((option) => option.textContent.trim()),
  }));
}

export function isEntryDisabled(text) {
  return entry(text).getAttribute('aria-disabled') === 'true';
}

// As a user does: the press of the button, then its release chooses
export function chooseEntry(text, options = {}) {
  const option = entry(text);
  option.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, ...options }));
  jQuery(option).trigger(jQuery.Event('mouseup', options));
}

// A key pressed in the field: in its search while it has one, else on the field
export function pressKey(select, key) {
  const instance = instanceOf(select);
  const target = instance.selection.$search?.[0] ||
    (instance.isOpen() ? instance.dropdown.$search[0] : instance.$selection[0]);
  const which = KEY_CODES[key];
  target.dispatchEvent(new KeyboardEvent('keydown', { key, keyCode: which, which, bubbles: true }));
}

// A click somewhere else on the page
export function clickOutside() {
  document.body.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
  jQuery(document.body).trigger('mousedown');
}

// Texts of the chosen entries of a multiple field
export function chosenTexts(select) {
  return Array.from(fieldElement(select).querySelectorAll('.select2-selection__choice'))
    .map((choice) => choice.getAttribute('title') || choice.textContent.replace('×', '').trim());
}

// What a single field shows: the chosen entry or its placeholder
export function shownElement(select) {
  return fieldElement(select).querySelector('.select2-selection__rendered');
}

export function shownText(select) {
  const shown = shownElement(select).cloneNode(true);
  shown.querySelector('.select2-selection__clear')?.remove();
  return shown.textContent.trim();
}

// The placeholder of an empty field
export function placeholderText(select) {
  const placeholder = fieldElement(select).querySelector('.select2-selection__placeholder');
  if (placeholder) { return placeholder.textContent.trim(); }

  return fieldElement(select).querySelector('.select2-search__field')?.getAttribute('placeholder') ?? null;
}

// Removes the chosen entry +text+ of a multiple field with its button
export function removeChosen(select, text) {
  const choice = Array.from(fieldElement(select).querySelectorAll('.select2-selection__choice'))
    .find((element) => element.getAttribute('title') === text);
  choice.querySelector('.select2-selection__choice__remove')
    .dispatchEvent(new MouseEvent('click', { bubbles: true }));
}

// The field offers to clear its value
export function canClear(select) {
  return fieldElement(select).querySelector('.select2-selection__clear') !== null;
}

export function clearField(select) {
  fieldElement(select).querySelector('.select2-selection__clear')
    .dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
}
