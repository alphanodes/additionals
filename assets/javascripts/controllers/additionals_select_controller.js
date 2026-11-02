import { Controller } from '@hotwired/stimulus';

// Select fields with search, entries from the server, tags and multiple
// values. The library behind them (Select2) is known to this file only:
// plugins render fields with the helpers of additionals, listen to events on
// the original <select> and use AdditionalsSelect from JavaScript.

const SEARCH_DELAY = 250;
const NAMESPACE = '.additionalsSelect';
const DEFAULT_WIDTH = '90%';
// sent by additionals_select_filters.js, which is loaded right after the
// library, also into content that comes later (render_async, dialogs)
const LIBRARY_LOADED = 'additionals-select:library-loaded';

// --- Renderers ---------------------------------------------------------------
// Entries of the server are plain values (names of people, tags, addresses),
// so text never goes through innerHTML. Only name_with_icon
// and avatar are html, built and escaped on the server.

function textSpan(text) {
  const span = document.createElement('span');
  span.textContent = text ?? '';
  return span;
}

function nameWithIcon(item) {
  if (item.loading) { return item.text; }
  if (item.name_with_icon === undefined) { return textSpan(item.text); }

  const span = document.createElement('span');
  span.innerHTML = item.name_with_icon;
  return span;
}

function avatarSpan(item) {
  const span = document.createElement('span');
  span.innerHTML = item.avatar || '';
  return span;
}

function withAvatar(item) {
  if (item.loading) { return item.text; }

  const span = avatarSpan(item);
  span.classList.add('additionals-select-avatar');
  span.append(`\u00a0${item.text ?? ''}`);
  return span;
}

function contact(item) {
  if (item.loading) { return item.text; }

  const span = avatarSpan(item);
  span.className = 'additionals-select-contact';
  const name = document.createElement('span');
  name.className = 'additionals-select-contact-name';
  name.textContent = item.text ?? '';
  const email = document.createElement('span');
  email.className = 'additionals-select-contact-email';
  email.textContent = item.email || '';
  span.append(name, email);
  return span;
}

function contactSelection(item) {
  const text = item.text || item.name || '';
  const email = typeof item.email === 'string' && item.email.trim().length ? item.email.trim() : '';
  // a typed address is its own text, it is not repeated
  if (email === '' || email === text) { return text; }

  return `${text} <${email}>`;
}

// The sprite path carries an asset digest, the server puts it on the option
function icon(item) {
  if (item.id === undefined || item.id === '') { return item.text; }

  const href = item.element?.dataset?.href;
  if (!href) { return textSpan(item.text); }

  const span = document.createElement('span');
  span.className = 'additionals-select-icon';
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', 's18 icon-svg');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
  use.setAttribute('href', href);
  svg.append(use);
  span.append(svg, ` ${item.text}`);
  return span;
}

// A color scheme of Chart.js with its colors. Group headings and schemes the
// colorschemes plugin does not know show their name only.
function colorScheme(item) {
  const span = document.createElement('span');
  span.className = 'colorscheme-option';
  span.append(textSpan(item.text));

  const [group, scheme] = (item.id || '').split('.');
  const colors = window.Chart?.colorschemes?.[group]?.[scheme];
  if (colors) {
    const swatches = document.createElement('span');
    swatches.className = 'colorscheme-swatches';
    colors.forEach((color) => {
      const swatch = document.createElement('span');
      swatch.className = 'colorscheme-swatch';
      swatch.style.backgroundColor = color;
      swatches.append(swatch);
    });
    span.append(swatches);
  }
  return span;
}

const RENDERERS = {
  name_with_icon: { result: nameWithIcon },
  avatar: { result: withAvatar },
  contact: { result: contact, selection: contactSelection },
  icon: { result: icon, selection: icon },
  color_scheme: { result: colorScheme, selection: colorScheme },
};

// --- Tags --------------------------------------------------------------------

// "a::b" belongs to the group "a", "a::b::c" to "a::b"
function tagGroup(tag) {
  const labels = tag.split('::').map((label) => label.trim());
  labels.pop();
  return labels.join('::');
}

// Values without the tags of the same group as +tag+, which replaces them
function withoutScopedSiblings(values, tag) {
  if (!tag.includes('::')) { return values; }

  const group = tagGroup(tag);
  return values.filter((value) => value === tag || !value.includes('::') || tagGroup(value) !== group);
}

// A pattern that is no regular expression checks nothing, rather than
// breaking the search with an error on every key
function fitsPattern(text, pattern) {
  if (!pattern) { return true; }

  try {
    return new RegExp(pattern).test(text);
  } catch {
    return true;
  }
}

function createTag(params) {
  const term = params.term.trim();
  // a comma separates tags, it is never part of one
  if (term === '' || term.includes(',')) { return null; }

  return { id: term, text: term };
}

// --- Library -----------------------------------------------------------------

function libraryAvailable() {
  return typeof window.jQuery === 'function' && typeof window.jQuery.fn.select2 === 'function';
}

function searchLabel() {
  return typeof window.ADDITIONALS_LABEL_SEARCH === 'undefined' ? '' : window.ADDITIONALS_LABEL_SEARCH;
}

// Entries of the server without the fields the library adds to them
function cleanItem(data) {
  const item = {};
  Object.keys(data).forEach((key) => {
    if (key.startsWith('_') || ['element', 'selected', 'disabled'].includes(key)) { return; }
    // entries of <option> elements get the empty title of the option
    if (key === 'title' && data.title === '') { return; }

    item[key] = data[key];
  });
  return item;
}

function buildLibraryOptions(config) {
  const renderer = RENDERERS[config.renderer] || RENDERERS.name_with_icon;
  const options = {
    placeholder: config.placeholder || '',
    allowClear: Boolean(config.allowClear),
    minimumInputLength: config.minInputLength || 0,
    width: config.width || DEFAULT_WIDTH,
    templateResult: renderer.result,
    tags: Boolean(config.tags),
  };
  if (renderer.selection) { options.templateSelection = renderer.selection; }
  if (config.dropdownParent) { options.dropdownParent = config.dropdownParent; }

  if (config.tags) {
    options.tokenSeparators = [','];
    options.createTag = createTag;
  }
  if (config.freeInput) {
    // found entries come first, Enter takes them; typed text that fits the
    // pattern is offered after them
    options.insertTag = (data, tag) => { data.push(tag); };
    options.createTag = (params) => {
      const tag = createTag(params);
      return tag && fitsPattern(tag.id, config.freeInputPattern) ? tag : null;
    };
  }

  if (config.url) {
    options.ajax = {
      url: config.url,
      dataType: 'json',
      delay: SEARCH_DELAY,
      data: (params) => ({ q: params.term }),
      processResults: (data) => ({ results: resultsWithValueKey(data, config.valueKey) }),
      cache: true,
    };
  }

  return options;
}

// The property +valueKey+ of an entry becomes its value, entries without it
// cannot be chosen (e.g. people without an address for a field of addresses)
function resultsWithValueKey(data, valueKey) {
  if (!valueKey) { return data; }

  return data.filter((item) => item[valueKey]).map((item) => ({ ...item, id: item[valueKey] }));
}

// The library triggers "change" through jQuery only, which never reaches
// listeners added with addEventListener (Stimulus actions among them). The
// change is sent as a native event instead, which jQuery handlers, native
// listeners and inline onchange attributes all receive exactly once.
function sendNativeChange(select, instance) {
  const { $element } = instance;
  const { trigger } = $element;
  $element.trigger = function (event, ...args) {
    if (event === 'change') {
      select.dispatchEvent(new Event('change', { bubbles: true }));
      return this;
    }
    return trigger.call(this, event, ...args);
  };
}

function initLibrary(select, config) {
  const $select = window.jQuery(select);
  $select.select2(buildLibraryOptions(config));
  const instance = $select.data('select2');
  sendNativeChange(select, instance);
  // plugins place and size the field by this class, not by the markup of
  // the library
  instance.$container[0].classList.add('additionals-select-field');

  // a message instead of entries ("searching", "no results") changes the
  // height of the list, which would otherwise stay where it opened
  instance.on('results:message', function () {
    this.dropdown._resizeDropdown();
    this.dropdown._positionDropdown();
  });

  const label = searchLabel();
  if (label) {
    $select.on(`select2:open${NAMESPACE}`, () => {
      instance.$dropdown.find('.select2-search__field').attr('placeholder', label);
    });
  }

  return instance;
}

function destroyLibrary(select) {
  const $select = window.jQuery(select);
  $select.off(NAMESPACE);
  if ($select.data('select2')) { $select.select2('destroy'); }
}

// Text typed into the field which is not chosen yet
function typedTerm(instance) {
  const $search = instance.selection.$search || instance.dropdown.$search;
  return $search ? String($search.val() || '').trim() : '';
}

// --- Controller --------------------------------------------------------------

class AdditionalsSelectController extends Controller {
  static values = {
    url: String,
    tags: Boolean,
    scopedTags: Boolean,
    freeInput: Boolean,
    freeInputPattern: String,
    renderer: String,
    valueKey: String,
    placeholder: String,
    allowClear: Boolean,
    minInputLength: Number,
    width: String,
  };

  connect() {
    if (!libraryAvailable()) {
      // the library comes with content loaded later, after this field
      this.waitForLibrary = () => this.connect();
      document.addEventListener(LIBRARY_LOADED, this.waitForLibrary, { once: true });
      return;
    }

    this.instance = initLibrary(this.element, this.config());
    this.bindEvents();
  }

  disconnect() {
    this.stopNotingActions();
    if (this.waitForLibrary) {
      document.removeEventListener(LIBRARY_LOADED, this.waitForLibrary);
      this.waitForLibrary = null;
    }
    if (!this.instance) { return; }

    destroyLibrary(this.element);
    this.instance = null;
  }

  config() {
    return {
      url: this.urlValue,
      // free input needs tags, the typed text becomes a value of its own
      tags: this.tagsValue || this.scopedTagsValue || this.freeInputValue,
      freeInput: this.freeInputValue,
      freeInputPattern: this.freeInputPatternValue,
      renderer: this.rendererValue,
      valueKey: this.valueKeyValue,
      placeholder: this.placeholderValue,
      allowClear: this.allowClearValue,
      minInputLength: this.minInputLengthValue,
      width: this.widthValue,
    };
  }

  bindEvents() {
    const $select = window.jQuery(this.element);

    $select.on(`select2:select${NAMESPACE}`, (event) => {
      this.dispatch('select', { detail: { item: cleanItem(event.params.data) } });
    });

    $select.on(`select2:selecting${NAMESPACE}`, (event) => {
      this.lastAction = 'choose';
      // before the library takes the tag, so its "change" tells the end result
      if (this.scopedTagsValue) { this.dropScopedSiblings(String(event.params.args.data.id)); }
    });

    // Removing an entry with Backspace puts its text into the search field,
    // which must not bring it back when the field is left
    $select.on(`select2:unselecting${NAMESPACE}`, () => { this.lastAction = 'choose'; });
    $select.on(`select2:unselect${NAMESPACE}`, (event) => { this.removedText = event.params.data.text; });

    if (this.freeInputValue) { this.bindFreeInput($select); }

    $select.on(`select2:close${NAMESPACE}`, () => this.dispatch('close'));
  }

  /* Free input takes the typed text when the field is left. The library
     clears the search when the list closes and tells a choice only after
     that (none at all for an entry already chosen), so what the user did
     last while the list was open decides: a choice in the list, Enter or
     Escape keep the text out; a click elsewhere, Tab or closing from a
     program take it. */
  bindFreeInput($select) {
    this.noteLastAction = (event) => { this.lastAction = this.actionOf(event); };

    $select.on(`select2:open${NAMESPACE}`, () => {
      this.lastAction = null;
      document.addEventListener('mousedown', this.noteLastAction, true);
      document.addEventListener('keydown', this.noteLastAction, true);
    });

    $select.on(`select2:closing${NAMESPACE}`, () => {
      if (this.lastAction !== 'choose' && this.lastAction !== 'cancel') { this.takeTypedValue(); }
    });

    $select.on(`select2:close${NAMESPACE}`, () => this.stopNotingActions());
  }

  actionOf(event) {
    if (event.type === 'keydown') {
      if (event.key === 'Escape') { return 'cancel'; }

      return event.key === 'Enter' ? 'choose' : null;
    }
    const { $container, $dropdown } = this.instance;
    if ($dropdown[0].contains(event.target) && event.target.closest('.select2-results__option')) { return 'choose'; }
    // removing a chosen entry (x) keeps the field open, it is no leaving
    if ($container[0].contains(event.target) || $dropdown[0].contains(event.target)) { return null; }

    return 'leave';
  }

  stopNotingActions() {
    if (!this.noteLastAction) { return; }

    document.removeEventListener('mousedown', this.noteLastAction, true);
    document.removeEventListener('keydown', this.noteLastAction, true);
  }

  // A tag "a::b" replaces a chosen tag of the same group, like "a::c"
  dropScopedSiblings(tag) {
    const values = this.currentValues();
    const kept = withoutScopedSiblings(values, tag);
    if (kept.length === values.length) { return; }

    Array.from(this.element.options).forEach((option) => {
      if (option.selected && !kept.includes(option.value)) { option.selected = false; }
    });
  }

  // Leaving the field takes what was typed, as a user expects from a field for
  // mail addresses
  takeTypedValue() {
    const term = typedTerm(this.instance);
    if (term === '' || term.includes(',') || term === this.removedText ||
        !fitsPattern(term, this.freeInputPatternValue)) { return; }

    let values = this.currentValues();
    if (values.includes(term)) { return; }
    if (this.scopedTagsValue) { values = withoutScopedSiblings(values, term); }

    if (!Array.from(this.element.options).some((option) => option.value === term)) {
      this.element.append(new Option(term, term, false, false));
    }
    this.setValues(this.element.multiple ? [...values, term] : [term]);
  }

  currentValues() {
    const value = window.jQuery(this.element).val();
    if (Array.isArray(value)) { return value; }

    return value ? [value] : [];
  }

  setValues(values) {
    window.jQuery(this.element).val(values);
    this.refresh();
  }

  // Shows values set from JavaScript and tells the listeners
  refresh() {
    this.element.dispatchEvent(new Event('change', { bubbles: true }));
  }

  open() {
    this.instance?.open();
  }
}

// A value changed after the field is set up (e.g. tags allowed or not after
// another choice in the form) sets the field up again. Stimulus also calls
// these before connect, when there is nothing to set up again yet.
Object.keys(AdditionalsSelectController.values).forEach((name) => {
  AdditionalsSelectController.prototype[`${name}ValueChanged`] = function valueChanged() {
    if (!this.instance) { return; }

    this.disconnect();
    this.connect();
  };
});

// --- JavaScript API ----------------------------------------------------------

function controllerFor(select) {
  return window.Stimulus?.getControllerForElementAndIdentifier(select, 'additionals-select') || null;
}

// Below +anchor+, starting at its left edge; where the window ends before the
// container does, it ends at the right edge of the anchor instead
function placeBelow(container, anchor) {
  const rect = anchor.getBoundingClientRect();
  const width = container.offsetWidth;
  const left = rect.left + width > document.documentElement.clientWidth ? Math.max(0, rect.right - width) : rect.left;
  Object.assign(container.style, {
    position: 'absolute',
    left: `${left + window.scrollX}px`,
    top: `${rect.bottom + window.scrollY}px`,
  });
}

// Opens a list of +entries+ ({ id, text }) below +anchor+ to pick one entry.
// It goes away after a choice, with Escape or a click outside of it.
function menu({ anchor, entries, placeholder = '', onSelect, onClose } = {}) {
  if (!libraryAvailable()) { return null; }

  const select = document.createElement('select');
  // a multiple select has its search field in place, the user types at once
  select.multiple = true;
  select.className = 'additionals-select-menu';
  entries.forEach((entry) => select.append(new Option(entry.text, entry.id)));
  document.body.append(select);

  // as wide as its longest entry, which the select itself measures
  const instance = initLibrary(select, { placeholder, width: 'resolve' });
  if (anchor) { placeBelow(instance.$container[0], anchor); }

  let chosen = false;
  const finish = () => {
    destroyLibrary(select);
    select.remove();
  };

  // The library closes the list before it tells the choice, so a choice is
  // known from "selecting" on
  const $select = window.jQuery(select);
  $select.on(`select2:selecting${NAMESPACE}`, () => { chosen = true; });
  $select.on(`select2:select${NAMESPACE}`, (event) => {
    const item = cleanItem(event.params.data);
    finish();
    if (onSelect) { onSelect(item); }
  });
  $select.on(`select2:close${NAMESPACE}`, () => {
    if (chosen) { return; }

    finish();
    if (onClose) { onClose(); }
  });

  instance.open();
  return select;
}

const AdditionalsSelect = {
  open(select) { controllerFor(select)?.open(); },
  refresh(select) {
    if (!select) { return; }

    const controller = controllerFor(select);
    if (controller) {
      controller.refresh();
    } else {
      select.dispatchEvent(new Event('change', { bubbles: true }));
    }
  },
  destroy(select) { controllerFor(select)?.disconnect(); },
  menu,
};

if (typeof window !== 'undefined') {
  window.AdditionalsSelect = AdditionalsSelect;
  if (window.Stimulus) {
    window.Stimulus.register('additionals-select', AdditionalsSelectController);
  }
}

export { AdditionalsSelect, RENDERERS, tagGroup, withoutScopedSiblings, createTag, resultsWithValueKey };
export default AdditionalsSelectController;
