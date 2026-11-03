import { Controller } from '@hotwired/stimulus';

// Select fields with search, entries from the server, tags and multiple
// values. The library behind them (Tom Select) is known to this file only:
// plugins render fields with the helpers of additionals, listen to events on
// the original <select> and use AdditionalsSelect from JavaScript.

const SEARCH_DELAY = 250;
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
  const span = avatarSpan(item);
  span.classList.add('additionals-select-avatar');
  span.append(`\u00a0${item.text ?? ''}`);
  return span;
}

function contact(item) {
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
// (data-href)
function icon(item) {
  if (!item.href) { return textSpan(item.text); }

  const span = document.createElement('span');
  span.className = 'additionals-select-icon';
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('class', 's18 icon-svg');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
  use.setAttribute('href', item.href);
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

  const [group, scheme] = String(item.id || '').split('.');
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

// The library takes a string of a template as html: text becomes a node, and
// every template gets an element of its own to put its classes on
function templateElement(content, className) {
  const element = document.createElement('div');
  if (className) { element.className = className; }
  element.append(typeof content === 'string' ? textSpan(content) : content);
  return element;
}

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

// --- Entries of the server ---------------------------------------------------

// The property +valueKey+ of an entry becomes its value, entries without it
// cannot be chosen (e.g. people without an address for a field of addresses)
function resultsWithValueKey(data, valueKey) {
  if (!valueKey) { return data; }

  return data.filter((item) => item[valueKey]).map((item) => ({ ...item, id: item[valueKey] }));
}

// The answer of the server as entries and groups of the library. An entry in
// several groups (e.g. watchers and active users) is one entry with all its
// groups; +order+ keeps the ids in the order of the answer.
function libraryEntries(data, valueKey) {
  const entries = new Map();
  const groups = [];
  const add = (item, group) => {
    const id = String(item.id);
    const known = entries.get(id);
    if (known) {
      if (group) { known.option.optgroup = [...[].concat(known.option.optgroup || []), group]; }
      return;
    }
    entries.set(id, { item, option: { ...item, id, optgroup: group } });
  };

  (Array.isArray(data) ? data : []).forEach((entry, index) => {
    if (!Array.isArray(entry.children)) {
      resultsWithValueKey([entry], valueKey).forEach((item) => add(item));
      return;
    }
    const group = `group-${index}`;
    groups.push({ value: group, label: entry.text });
    resultsWithValueKey(entry.children, valueKey).forEach((item) => add(item, group));
  });

  return { entries, groups };
}

function searchUrl(url, term) {
  const target = new URL(url, window.location.href);
  if (term) { target.searchParams.set('q', term); }
  return target.toString();
}

// --- Library -----------------------------------------------------------------

function libraryAvailable() {
  return typeof window.TomSelect === 'function';
}

function searchLabel() {
  return typeof window.ADDITIONALS_LABEL_SEARCH === 'undefined' ? '' : window.ADDITIONALS_LABEL_SEARCH;
}

function libraryPlugins(config, multiple) {
  const plugins = multiple ? ['remove_button'] : ['dropdown_input'];
  if (config.allowClear) { plugins.push('clear_button'); }
  return plugins;
}

function buildLibraryOptions(config, multiple) {
  const renderer = RENDERERS[config.renderer] || RENDERERS.name_with_icon;
  const options = {
    valueField: 'id',
    labelField: 'text',
    searchField: ['text'],
    plugins: libraryPlugins(config, multiple),
    placeholder: config.placeholder || '',
    hidePlaceholder: true,
    hideSelected: false,
    closeAfterSelect: true,
    maxOptions: null,
    refreshThrottle: 0,
    dropdownParent: 'body',
    // a single field without a value is no deletion of it
    onDelete: () => multiple,
    render: {
      option: (data) => templateElement(renderer.result(data)),
      // the title holds the text alone, without the button that removes it
      item: (data) => {
        const element = templateElement(renderer.selection ? renderer.selection(data) : data.text);
        element.title = data.text ?? '';
        return element;
      },
      // the entry for typed text shows the text only
      option_create: (data) => templateElement(data.input, 'create'),
    },
  };

  if (config.tags) {
    options.create = (input) => createTag({ term: input });
    options.createFilter = function (input) {
      const tag = createTag({ term: input });
      return tag !== null && !this.options[tag.id] && (!config.freeInput || fitsPattern(tag.id, config.freeInputPattern));
    };
  }

  return options;
}

// What the user typed into the field and has not chosen yet
function typedTerm(instance) {
  return instance.control_input.value.trim();
}

function chosenValues(select) {
  return Array.from(select.selectedOptions).map((option) => option.value).filter((value) => value !== '');
}

// The entry behind +value+ as the server sent it, or as its <option> has it
function itemOf(field, value) {
  return field.serverItems.get(value) || { id: value, text: field.instance.options[value]?.text ?? value };
}

// Entries of the server: the list shows exactly the answer of the last search,
// in its order, and asks the server again on each search and on each opening
function serverOptions(field, config) {
  return {
    loadThrottle: SEARCH_DELAY,
    shouldLoad: (query) => query.length >= (config.minInputLength || 0),
    load: (query, callback) => {
      fetch(searchUrl(config.url, query), {
        headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
        credentials: 'same-origin',
      })
        .then((response) => (response.ok ? response.json() : []))
        .catch(() => [])
        .then((data) => {
          const { instance } = field;
          // an answer after the list closed (e.g. after a choice) would open
          // it again; the next opening asks the server anew
          if (!instance.isOpen) {
            instance.loading = Math.max(instance.loading - 1, 0);
            if (!instance.loading) { instance.wrapper.classList.remove(instance.settings.loadingClass); }
            return;
          }

          const { entries, groups } = libraryEntries(data, config.valueKey);
          entries.forEach(({ item }, id) => field.serverItems.set(id, item));
          field.answer = Array.from(entries.keys());
          instance.clearOptions();
          instance.clearOptionGroups();
          callback(Array.from(entries.values()).map(({ option }) => option), groups);
        });
    },
  };
}

function bindServer(field) {
  const { instance } = field;

  // the same search again may find something else by now
  instance.hook('before', 'load', () => { instance.loadedSearches = {}; });

  instance.search = function (query) {
    this.lastQuery = query;
    const items = field.answer.filter((id) => this.options[id]).map((id) => ({ id, score: 1 }));
    this.currentResults = { items, query: '', tokens: [], options: {}, total: items.length };
    return this.currentResults;
  };

  instance.on('dropdown_open', () => {
    const query = typedTerm(instance);
    if (instance.settings.shouldLoad(query)) { instance.load(query); }
  });
}

function initLibrary(select, config) {
  const { multiple } = select;
  // the field gets the classes of the select from the library, which would
  // count it as a select of the page (e.g. ".values .value" of query filters)
  const classes = Array.from(select.classList);
  const field = { instance: null, serverItems: new Map(), answer: [] };
  const options = buildLibraryOptions(config, multiple);
  if (config.url) { Object.assign(options, serverOptions(field, config)); }

  const instance = new window.TomSelect(select, options);
  field.instance = instance;

  instance.wrapper.classList.remove(...classes);
  // plugins place and size the field by this class, not by the markup of
  // the library
  instance.wrapper.classList.add('additionals-select-field');
  instance.dropdown.classList.add('additionals-select-dropdown');
  if (config.width !== 'auto') { instance.wrapper.style.width = config.width || DEFAULT_WIDTH; }

  if (config.url) { bindServer(field); }

  // typed text of free input comes after the found entries
  if (config.freeInput) {
    instance.hook('after', 'refreshOptions', () => {
      const create = instance.dropdown_content.querySelector('.create');
      if (create) { instance.dropdown_content.append(create); }
    });
  }

  // Closing the list of a single field gives the focus back to the field,
  // which closes it once more inside and would open it again
  let closing = 0;
  instance.hook('before', 'close', () => { closing += 1; });
  instance.hook('after', 'close', () => { closing -= 1; });
  const { open } = instance;
  instance.open = function () {
    if (closing === 0) { open.call(this); }
  };

  // a click on a chosen entry opens the list like a click elsewhere in the
  // field, it does not mark the entry
  instance.onItemSelect = () => false;

  // a chosen entry of a multiple field is chosen again to remove it
  const { onOptionSelect } = instance;
  instance.onOptionSelect = function (event, option) {
    const { value } = option.dataset;
    if (multiple && value !== undefined && this.items.includes(value)) {
      this.removeItem(value);
      this.close();
      return;
    }
    onOptionSelect.call(this, event, option);
  };

  if (!multiple) {
    const search = instance.dropdown.querySelector('.dropdown-input');
    if (search) { search.placeholder = searchLabel(); }
  }

  return field;
}

// Takes the options, values and state of the select into the field. The
// sync() of the library reads the select with its default fields, not with
// the fields of this field (id, text).
function syncLibrary(instance, select) {
  Array.from(select.options).forEach((option) => {
    if (option.value === '' || instance.options[option.value]) { return; }

    instance.addOption({ ...option.dataset, id: option.value, text: option.text, disabled: option.disabled, $option: option });
  });
  const values = chosenValues(select);
  instance.setValue(select.multiple ? values : values.slice(0, 1), true);
  if (select.disabled) {
    instance.disable();
  } else {
    instance.enable();
  }
  instance.lastQuery = null;
}

// The library puts the options of the select back as they were before it,
// the options and values of now stay
function destroyLibrary(select) {
  const { tomselect } = select;
  if (!tomselect) { return; }

  const nodes = Array.from(select.children);
  const values = Array.from(select.selectedOptions).map((option) => option.value);
  tomselect.destroy();
  select.replaceChildren(...nodes);
  Array.from(select.options).forEach((option) => { option.selected = values.includes(option.value); });
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

    this.field = initLibrary(this.element, this.config());
    this.instance = this.field.instance;
    this.bindEvents();
    this.followSelect();
  }

  disconnect() {
    this.stopNotingActions();
    if (this.waitForLibrary) {
      document.removeEventListener(LIBRARY_LOADED, this.waitForLibrary);
      this.waitForLibrary = null;
    }
    if (!this.instance) { return; }

    this.observer?.disconnect();
    this.element.removeEventListener('change', this.syncOnChange);
    destroyLibrary(this.element);
    this.instance = null;
    this.field = null;
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
    const { instance } = this;

    // only a choice of the user is told, not values set from a program
    let choosing = false;
    instance.hook('before', 'onOptionSelect', () => { choosing = true; });
    instance.hook('after', 'onOptionSelect', () => { choosing = false; });
    instance.on('item_add', (value) => {
      if (choosing) { this.dispatch('select', { detail: { item: itemOf(this.field, value) } }); }
    });

    // before the library takes the tag, so its "change" tells the end result
    if (this.scopedTagsValue) {
      instance.hook('before', 'addItem', (value, silent) => {
        if (!silent) { this.dropScopedSiblings(String(value)); }
      });
    }

    if (this.freeInputValue) { this.bindFreeInput(); }

    // closing the list of a single field moves the focus, which closes it a
    // second time inside the library
    let closed = true;
    instance.on('dropdown_open', () => { closed = false; });
    instance.on('dropdown_close', () => {
      if (closed) { return; }

      closed = true;
      this.dispatch('close');
    });
  }

  /* Changes of the select from a program (appended options, values set from
     JavaScript and told by "change", disabled) are taken by the field. */
  followSelect() {
    this.syncOnChange = () => {
      const values = chosenValues(this.element);
      if (values.join('\n') !== this.instance.items.join('\n')) { syncLibrary(this.instance, this.element); }
    };
    this.element.addEventListener('change', this.syncOnChange);

    this.observer = new MutationObserver((mutations) => {
      const unknownOption = mutations.some((mutation) => Array.from(mutation.addedNodes).some((node) => (
        node.tagName === 'OPTION' && node.value !== '' && !this.instance.options[node.value])));
      const disabled = mutations.some((mutation) => mutation.attributeName === 'disabled');
      if (unknownOption || disabled) { syncLibrary(this.instance, this.element); }
    });
    this.observer.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled'] });
  }

  /* Free input takes the typed text when the field is left. The library
     clears the search when the list closes, so the text is read right before.
     What the user did last while the list was open decides: a choice in the
     list, Enter or Escape keep the text out; a click elsewhere, Tab or closing
     from a program take it. */
  bindFreeInput() {
    const { instance } = this;
    this.noteLastAction = (event) => { this.lastAction = this.actionOf(event); };

    instance.on('dropdown_open', () => {
      this.lastAction = null;
      document.addEventListener('mousedown', this.noteLastAction, true);
      document.addEventListener('keydown', this.noteLastAction, true);
    });

    let typed = '';
    instance.hook('before', 'close', () => {
      typed = instance.isOpen && this.lastAction !== 'choose' && this.lastAction !== 'cancel' ? typedTerm(instance) : '';
    });
    instance.hook('after', 'close', () => {
      const term = typed;
      typed = '';
      this.stopNotingActions();
      if (term !== '') { this.takeTypedValue(term); }
    });
  }

  actionOf(event) {
    if (event.type === 'keydown') {
      if (event.key === 'Escape') { return 'cancel'; }

      return event.key === 'Enter' ? 'choose' : null;
    }
    const { wrapper, dropdown } = this.instance;
    if (dropdown.contains(event.target) && event.target.closest('[data-selectable]')) { return 'choose'; }
    // removing a chosen entry (x) keeps the field open, it is no leaving
    if (wrapper.contains(event.target) || dropdown.contains(event.target)) { return null; }

    return 'leave';
  }

  stopNotingActions() {
    if (!this.noteLastAction) { return; }

    document.removeEventListener('mousedown', this.noteLastAction, true);
    document.removeEventListener('keydown', this.noteLastAction, true);
  }

  // A tag "a::b" replaces a chosen tag of the same group, like "a::c"
  dropScopedSiblings(tag) {
    const values = [...this.instance.items];
    const kept = withoutScopedSiblings(values, tag);
    values.filter((value) => !kept.includes(value)).forEach((value) => this.instance.removeItem(value, true));
  }

  // Leaving the field takes what was typed, as a user expects from a field for
  // mail addresses
  takeTypedValue(term) {
    if (term.includes(',') || !fitsPattern(term, this.freeInputPatternValue)) { return; }

    let values = [...this.instance.items];
    if (values.includes(term)) { return; }
    if (this.scopedTagsValue) { values = withoutScopedSiblings(values, term); }

    if (!this.instance.options[term]) { this.instance.addOption({ id: term, text: term }, true); }
    this.instance.setValue(this.element.multiple ? [...values, term] : [term]);
  }

  // Shows values set from JavaScript and tells the listeners
  refresh() {
    if (this.instance) { syncLibrary(this.instance, this.element); }
    this.element.dispatchEvent(new Event('change', { bubbles: true }));
  }

  open() {
    if (!this.instance) { return; }

    this.instance.open();
    this.instance.refreshOptions(false);
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

  const field = initLibrary(select, { placeholder, width: 'auto' });
  const { instance } = field;
  instance.wrapper.classList.add('additionals-select-menu-field');
  if (anchor) { placeBelow(instance.wrapper, anchor); }

  let done = false;
  const finish = () => {
    done = true;
    destroyLibrary(select);
    select.remove();
  };

  instance.on('item_add', (value) => {
    if (done) { return; }

    const item = itemOf(field, value);
    finish();
    if (onSelect) { onSelect(item); }
  });
  instance.on('dropdown_close', () => {
    if (done) { return; }

    finish();
    if (onClose) { onClose(); }
  });

  // a click elsewhere closes the menu at once, also before the library has
  // taken the focus
  const closeOutside = (event) => {
    if (!instance.wrapper.contains(event.target) && !instance.dropdown.contains(event.target)) { instance.close(); }
  };
  document.addEventListener('mousedown', closeOutside, true);
  instance.on('destroy', () => document.removeEventListener('mousedown', closeOutside, true));

  instance.open();
  instance.refreshOptions(false);
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
