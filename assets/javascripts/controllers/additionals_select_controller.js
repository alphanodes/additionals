import { Controller } from '@hotwired/stimulus';

// Select fields with search, entries from the server, tags and multiple
// values. The library behind them (Tom Select) is known to this file only:
// plugins render fields with the helpers of additionals, listen to events on
// the original <select> and use AdditionalsSelect from JavaScript.

const SEARCH_DELAY = 250;
const DEFAULT_WIDTH = '90%';
const ENTER_KEY = 13;
const ARROW_DOWN_KEY = 40;
const TAB_KEY = 9;
const BACKSPACE_KEY = 8;
const DELETE_KEY = 46;
// names a data attribute can take
const DATA_KEY = /^[a-z][a-z0-9_]*$/i;
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
// groups; +order+ keeps the ids in the order of the answer. An entry on top
// without a group stays there: "<< me >>" of a form field carries the id of
// the user, who is in a group of the answer too, and the library knows each
// value once.
function libraryEntries(data, valueKey) {
  const entries = new Map();
  const groups = [];
  const add = (item, group) => {
    const id = String(item.id);
    const known = entries.get(id);
    if (known) {
      if (group && known.option.optgroup !== undefined) {
        known.option.optgroup = [...[].concat(known.option.optgroup), group];
      }
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

// Texts of the page language (additionals_select_labels), the library has
// English ones of its own
function selectLabel(name) {
  return window.ADDITIONALS_SELECT_LABELS?.[name] || '';
}

function libraryPlugins(config, multiple) {
  const plugins = {};
  if (multiple) {
    plugins.remove_button = selectLabel('remove') ? { title: selectLabel('remove') } : {};
  } else {
    plugins.dropdown_input = {};
  }
  // the button empties the field with a click, Tab goes on to the next field
  if (config.allowClear) { plugins.clear_button = { tabindex: -1, ...(selectLabel('clear') ? { title: selectLabel('clear') } : {}) }; }
  return plugins;
}

// A search keeps the order of the list, as a select does
function inListOrder(a, b) {
  return this.items[a.id].$order - this.items[b.id].$order;
}

// Plugins add renderers of their own to the global additionalsSelectRenderers
// (e.g. tags with their colors), looked up when the field is set up. Built-in
// ones come first; own keys only, so a name like "constructor" is no renderer.
function lookupRenderer(name) {
  if (Object.hasOwn(RENDERERS, name)) { return RENDERERS[name]; }

  const registered = window.additionalsSelectRenderers;
  return registered && Object.hasOwn(registered, name) ? registered[name] : RENDERERS.name_with_icon;
}

function buildLibraryOptions(config, multiple) {
  const renderer = lookupRenderer(config.renderer);
  const options = {
    valueField: 'id',
    labelField: 'text',
    searchField: ['text'],
    plugins: libraryPlugins(config, multiple),
    placeholder: config.placeholder || '',
    openOnFocus: false,
    hidePlaceholder: true,
    hideSelected: false,
    closeAfterSelect: true,
    maxOptions: null,
    sortField: inListOrder,
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
      // nothing found is no message while typed text is offered as new entry
      no_results(data) {
        if (this.canCreate(data.input)) { return null; }

        return templateElement(selectLabel('noResults') || 'No results found', 'no-results');
      },
      // a field without any entry of its own, none of the server and no new
      // ones says so, instead of opening nothing
      not_loading() {
        if (config.url || config.tags || Object.keys(this.options).some((value) => value !== '')) { return null; }

        return templateElement(selectLabel('noResults') || 'No results found', 'no-results');
      },
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

// A request whose answer is not wanted any longer: the loading state of the
// library ends without taking the answer
function dropAnswer(instance) {
  instance.loading = Math.max(instance.loading - 1, 0);
  if (!instance.loading) { instance.wrapper.classList.remove(instance.settings.loadingClass); }
}

// Entries of the server: the list shows exactly the answer to the search in
// the field, in its order, and asks the server again on each search and on
// each opening. Answers arrive in any order, only the one to the last request
// counts; one that arrives after the list closed (e.g. after a choice) would
// open it again, the next opening asks anew.
function serverOptions(field, config) {
  return {
    loadThrottle: SEARCH_DELAY,
    shouldLoad: (query) => query.length >= (config.minInputLength || 0),
    load: (query, callback) => {
      const { instance } = field;
      if (field.gone) {
        dropAnswer(instance);
        return;
      }

      field.request += 1;
      const { request } = field;
      fetch(searchUrl(config.url, query), {
        headers: { Accept: 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
        credentials: 'same-origin',
      })
        .then((response) => (response.ok ? response.json() : []))
        .catch(() => [])
        .then((data) => {
          if (field.gone || request !== field.request || !instance.isOpen) {
            dropAnswer(instance);
            return;
          }

          const { entries, groups } = libraryEntries(data, config.valueKey);
          entries.forEach(({ item }, id) => field.serverItems.set(id, item));
          field.answer = { query, ids: Array.from(entries.keys()) };
          instance.clearOptions();
          instance.clearOptionGroups();
          // an entry keeps the <option> it has in the select (chosen now or
          // before), the library would add a second one
          const options = Array.from(entries.values()).map(({ option }) => {
            const element = Array.from(instance.input.options).find((item) => item.value === option.id);
            return element ? { ...option, $option: element } : option;
          });
          callback(options, groups);
        });
    },
  };
}

// The <option> of a chosen entry of the server carries its data, so the field
// shows it the same after it is set up again (e.g. the address of a contact)
function keepServerData(field) {
  field.instance.items.forEach((value) => {
    const item = field.serverItems.get(value);
    const option = field.instance.options[value]?.$option;
    if (!item || !option) { return; }

    Object.entries(item).forEach(([key, data]) => {
      if (DATA_KEY.test(key) && key !== 'id' && key !== 'text' && ['string', 'number'].includes(typeof data)) {
        option.dataset[key] = data;
      }
    });
  });
}

function bindServer(field) {
  const { instance } = field;

  instance.on('change', () => keepServerData(field));

  // the same search again may find something else by now
  instance.hook('before', 'load', () => { instance.loadedSearches = {}; });

  // only the answer to the search in the field, none to an earlier one
  instance.search = function (query) {
    this.lastQuery = query;
    const ids = field.answer.query === query ? field.answer.ids : [];
    const items = ids.filter((id) => this.options[id]).map((id) => ({ id, score: 1 }));
    this.currentResults = { items, query: '', tokens: [], options: {}, total: items.length };
    return this.currentResults;
  };

  instance.on('dropdown_open', () => {
    const query = typedTerm(instance);
    if (instance.settings.shouldLoad(query)) { instance.load(query); }
  });
  instance.on('dropdown_close', () => { field.answer = { query: null, ids: [] }; });
}

// A modal dialog of jQuery UI keeps the focus inside the dialog. The list of
// a field hangs at the body, its search may take the focus too.
function allowListsInDialogs() {
  const dialog = window.jQuery?.ui?.dialog;
  if (!dialog || dialog.prototype.additionalsSelectAllowed) { return; }

  const { _allowInteraction: allowInteraction } = dialog.prototype;
  dialog.prototype._allowInteraction = function (event) {
    return Boolean(event.target.closest?.('.additionals-select-dropdown')) || allowInteraction.call(this, event);
  };
  dialog.prototype.additionalsSelectAllowed = true;
}

// Opens the list also when it has no entries yet (entries of the server). The
// marked entry, the chosen one of a single field, is in sight at once: the
// library jumps there only when it opens the list itself, otherwise the list
// glides there (scroll-behavior of tom-select.css) or stays at its top.
function openList(instance) {
  instance.open();
  instance.refreshOptions(false);
  if (instance.activeOption) { instance.scrollToOption(instance.activeOption, 'auto'); }
}

function initLibrary(select, config) {
  allowListsInDialogs();
  const { multiple } = select;
  // the field gets the classes of the select from the library, which would
  // count it as a select of the page (e.g. ".values .value" of query filters)
  const classes = Array.from(select.classList);
  const field = { instance: null, serverItems: new Map(), answer: { query: null, ids: [] }, request: 0, gone: false };
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

  // Pressing the field takes the focus from a field elsewhere, as the browser
  // does for its own select. The library keeps it there (preventDefault on
  // mousedown) and moves it by script afterwards; Firefox then puts it back
  // into a field showing its input history (e.g. the first field, focused by
  // Redmine when the page loads), which closes the list again.
  instance.wrapper.addEventListener('mousedown', () => {
    const focused = document.activeElement;
    if (instance.isLocked || !focused || focused === document.body) { return; }
    if (instance.wrapper.contains(focused) || instance.dropdown.contains(focused)) { return; }

    focused.blur();
  }, true);

  // The list opens with a click, Enter or the arrow down, not when the field
  // only gets the focus (e.g. with Tab); a click on the open field closes it
  instance.onClick = function () {
    // entries marked with the arrow keys are no longer marked, as in the library
    if (this.activeItems.length) { this.clearActiveItems(); }
    if (this.isFocused && this.isOpen) {
      this.blur();
      return;
    }
    openList(this);
  };

  // Enter or the arrow down on the closed field opens its list, also when it
  // has no entries yet (entries of the server); Enter submits no form then
  const { onKeyDown } = instance;
  instance.onKeyDown = function (event) {
    if ([ENTER_KEY, ARROW_DOWN_KEY].includes(event.keyCode) && !this.isOpen && !this.isLocked) {
      event.preventDefault();
      openList(this);
      return;
    }
    // the search of a single field sits in the list at the end of the page:
    // closing it first gives the focus to the field, so the browser goes on
    // from there to the next or previous field
    if (event.keyCode === TAB_KEY && this.isOpen && !multiple) {
      this.close();
      return;
    }
    // a field that may be emptied with its button may be with the keyboard too
    if ([BACKSPACE_KEY, DELETE_KEY].includes(event.keyCode) && config.allowClear && !multiple &&
        !this.isOpen && !this.isLocked && this.items.length) {
      event.preventDefault();
      this.clear();
      return;
    }
    onKeyDown.call(this, event);
  };

  // the list opens above the field where the window has no room below it but
  // above, as a native select does
  instance.hook('after', 'positionDropdown', () => {
    const { dropdown } = instance;
    const rect = instance.control.getBoundingClientRect();
    const below = window.innerHeight - rect.bottom;
    const above = dropdown.offsetHeight > below && rect.top > below;
    dropdown.classList.toggle('additionals-select-dropup', above);
    if (above) { dropdown.style.top = `${rect.top + window.scrollY - dropdown.offsetHeight}px`; }
  });
  instance.hook('after', 'refreshOptions', () => {
    if (instance.isOpen) { instance.positionDropdown(); }
  });

  // the list hangs at the body and follows the field when a container around
  // it scrolls (a dialog, the sidebar), not only the window
  const followScroll = (event) => {
    if (!instance.dropdown.contains(event.target)) { instance.positionDropdown(); }
  };
  instance.on('dropdown_open', () => document.addEventListener('scroll', followScroll, true));
  instance.on('dropdown_close', () => document.removeEventListener('scroll', followScroll, true));
  instance.on('destroy', () => document.removeEventListener('scroll', followScroll, true));

  // a click on a chosen entry opens the list like a click elsewhere in the
  // field, it does not mark the entry
  instance.onItemSelect = () => false;

  // A value chosen as a suggestion (e.g. "<< me >>" of a new filter, as core
  // does) gives way to the first other entry the user chooses, as the value
  // of a single select would, or is taken when the user chooses it; after
  // that the field adds entries as usual. Until then it is shown as one.
  let suggestion = multiple && config.suggestion ? config.suggestion : null;
  const showSuggestion = (shown) => {
    instance.getItem(config.suggestion)?.classList.toggle('additionals-select-suggestion', shown);
  };
  const endSuggestion = () => {
    suggestion = null;
    showSuggestion(false);
  };
  if (suggestion !== null) {
    showSuggestion(true);
    instance.hook('before', 'addItem', (value, silent) => {
      if (silent || suggestion === null) { return; }

      const replaced = suggestion;
      endSuggestion();
      if (value !== replaced && instance.items.includes(replaced)) { instance.removeItem(replaced, true); }
    });
    instance.on('item_remove', endSuggestion);
  }

  // a chosen entry of a multiple field is chosen again to remove it; the
  // suggestion chosen by the user is taken instead
  const { onOptionSelect } = instance;
  instance.onOptionSelect = function (event, option) {
    const { value } = option.dataset;
    if (value !== undefined && value === suggestion) {
      endSuggestion();
      this.close();
      return;
    }
    if (multiple && value !== undefined && this.items.includes(value)) {
      this.removeItem(value);
      this.close();
      return;
    }
    onOptionSelect.call(this, event, option);
  };

  if (multiple) {
    instance.dropdown_content.setAttribute('aria-multiselectable', 'true');
  } else {
    describeSearch(instance);
  }

  return field;
}

// The search of a single field has the focus while its list is open: it
// carries the name of the field and the entry marked in the list, which the
// library sets on the field only
function describeSearch(instance) {
  const search = instance.control_input;
  const { control } = instance;
  search.placeholder = selectLabel('search');
  search.setAttribute('role', 'combobox');
  search.setAttribute('aria-autocomplete', 'list');
  search.setAttribute('aria-expanded', 'true');
  ['aria-controls', 'aria-labelledby', 'aria-label'].forEach((name) => {
    const value = control.getAttribute(name) || instance.input.getAttribute(name);
    if (value) { search.setAttribute(name, value); }
  });
  const markEntry = () => {
    const marked = control.getAttribute('aria-activedescendant');
    if (marked) {
      search.setAttribute('aria-activedescendant', marked);
    } else {
      search.removeAttribute('aria-activedescendant');
    }
  };
  instance.hook('after', 'setActiveOption', markEntry);
  instance.hook('after', 'clearActiveOption', markEntry);
}

// Takes the options, values and state of the select into the field. The
// sync() of the library reads the select with its default fields, not with
// the fields of this field (id, text).
// Options removed from the select go too, except for fields with entries of
// the server, which are no options of the select. The state changes only when
// it differs: setting it writes the attribute, which would sync again.
function syncLibrary(instance, select, { fromServer = false } = {}) {
  // A value without an option leaves a single select with nothing chosen. The
  // library would move the empty option without choosing it, and the browser
  // would choose the first other option in its place. Removing options below
  // lets the library do this already, so this comes first.
  if (!select.multiple && select.selectedIndex === -1) {
    const empty = Array.from(select.options).find((option) => option.value === '');
    if (empty) { empty.selected = true; }
  }
  const values = Array.from(select.options).map((option) => option.value);
  if (!fromServer) {
    Object.keys(instance.options).filter((value) => !values.includes(value)).forEach((value) => {
      instance.removeOption(value, true);
    });
  }
  Array.from(select.options).forEach((option) => {
    if (option.value === '' || instance.options[option.value]) { return; }

    instance.addOption({ ...option.dataset, id: option.value, text: option.text, disabled: option.disabled, $option: option });
  });
  const chosen = chosenValues(select);
  instance.setValue(select.multiple ? chosen : chosen.slice(0, 1), true);
  if (select.disabled !== instance.isDisabled) {
    if (select.disabled) {
      instance.disable();
    } else {
      instance.enable();
    }
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

// The options of an added or removed node: itself or those of its group
function optionsOf(node) {
  if (node.tagName === 'OPTION') { return [node]; }

  return node.tagName === 'OPTGROUP' ? Array.from(node.querySelectorAll('option')) : [];
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
    suggestion: String,
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
    // a search on its way asks nothing and takes no answer any longer
    this.field.gone = true;
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
      suggestion: this.suggestionValue,
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

    instance.on('dropdown_close', () => this.dispatch('close'));
  }

  /* Changes of the select from a program (appended options, values set from
     JavaScript and told by "change", disabled) are taken by the field. */
  followSelect() {
    this.syncOnChange = () => {
      const values = chosenValues(this.element);
      if (values.join('\n') !== this.instance.items.join('\n')) { this.sync(); }
    };
    this.element.addEventListener('change', this.syncOnChange);

    this.observer = new MutationObserver((mutations) => {
      const unknownOption = mutations.some((mutation) => Array.from(mutation.addedNodes).some((node) => (
        optionsOf(node).some((option) => option.value !== '' && !this.instance.options[option.value]))));
      // the library moves chosen options to the end, only gone ones count
      const removedOption = mutations.some((mutation) => Array.from(mutation.removedNodes).some((node) => (
        optionsOf(node).length > 0 && !this.element.contains(node))));
      const disabled = mutations.some((mutation) => mutation.attributeName === 'disabled');
      if (unknownOption || removedOption || disabled) { this.sync(); }
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

    // a tag of the same group goes in the hook before addItem
    const values = [...this.instance.items];
    if (values.includes(term)) { return; }

    if (!this.instance.options[term]) { this.instance.addOption({ id: term, text: term }, true); }
    this.instance.setValue(this.element.multiple ? [...values, term] : [term]);
  }

  sync() {
    syncLibrary(this.instance, this.element, { fromServer: Boolean(this.urlValue) });
  }

  // Shows values set from JavaScript and tells the listeners
  refresh() {
    if (this.instance) { this.sync(); }
    this.element.dispatchEvent(new Event('change', { bubbles: true }));
  }

  open() {
    if (!this.instance) { return; }

    openList(this.instance);
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

  // the focus goes back where it was after Escape, not to the page
  const before = document.activeElement;
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
    if (document.activeElement === document.body && before?.isConnected) { before.focus(); }
    if (onClose) { onClose(); }
  });

  // a click elsewhere closes the menu at once, also before the library has
  // taken the focus
  const closeOutside = (event) => {
    if (!instance.wrapper.contains(event.target) && !instance.dropdown.contains(event.target)) { instance.close(); }
  };
  document.addEventListener('mousedown', closeOutside, true);
  instance.on('destroy', () => document.removeEventListener('mousedown', closeOutside, true));

  openList(instance);
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
