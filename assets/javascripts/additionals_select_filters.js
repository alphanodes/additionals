/* Select fields for the value of query filters.

   Filters are registered by additionals_select_filter (Ruby) in
   additionalsSelectFilters, by filter type, field format or field name. The
   rows Redmine builds for such a filter get the Stimulus controller
   additionals-select, which sets the field up.

   Content loaded later (dialogs, render_async) can bring this script again:
   it only uses var and function at the top and wraps buildFilterRow once. */

/* global availableFilters, operatorByType, buildFilterRow:writable, enableValues:writable */

var additionalsSelectFilters = window.additionalsSelectFilters || { type: {}, fieldFormat: {}, field: {} }; // eslint-disable-line no-var
window.additionalsSelectFilters = additionalsSelectFilters;

var ADDITIONALS_SELECT_VALUE_KEYS = ['url', 'tags', 'scopedTags', 'freeInput', 'freeInputPattern', 'renderer', // eslint-disable-line no-var
  'valueKey', 'placeholder', 'allowClear', 'minInputLength', 'width', 'suggestion'];

// The options of the filter +field+: a field name wins over its field format,
// which wins over its filter type
function additionalsSelectFilterOptions(field) {
  const filter = typeof availableFilters === 'undefined' ? undefined : availableFilters[field];
  if (!filter) { return undefined; }

  return additionalsSelectFilters.field[field] ||
    (filter.field_format && additionalsSelectFilters.fieldFormat[filter.field_format]) ||
    additionalsSelectFilters.type[filter.type];
}

/* Turns +select+ into a select field with +options+ (keys like the values of
   the controller: url, tags, renderer, minInputLength, ...). Also used for
   rows a plugin builds itself. +values+ are the chosen values: given for a
   single select, an empty list chooses nothing, the browser would choose
   its first option. */
/* exported additionalsSelectApply */
function additionalsSelectApply(select, options) {
  const values = options.values && options.values.map(String);
  if (options.multiple !== false) {
    additionalsSelectMultiple(select, values);
  } else if (values) {
    additionalsSelectSingle(select, values);
  }

  ADDITIONALS_SELECT_VALUE_KEYS.forEach((key) => {
    const value = options[key];
    if (value === undefined || value === null || value === false || value === '') { return; }

    const attribute = key.replace(/[A-Z]/g, (char) => `-${char.toLowerCase()}`);
    select.setAttribute(`data-additionals-select-${attribute}-value`, value);
  });
  // last, so the controller connects with all values set
  select.setAttribute('data-controller', 'additionals-select');
}

/* A single select with the values of its row gets a blank option, the empty
   value of the field, and chooses the first of +values+ or nothing */
function additionalsSelectSingle(select, values) {
  if (!Array.from(select.options).some((option) => option.value === '')) { select.prepend(new Option('', '')); }
  select.value = values.length > 0 ? values[0] : '';
  // a value without an option chooses nothing, the library would then take
  // the first option as value
  if (select.selectedIndex === -1) { select.value = ''; }
}

/* Makes +select+ take multiple values. A single select always has an option
   selected, the first one if none is chosen; that must not become a value. */
function additionalsSelectMultiple(select, values) {
  if (select.multiple) { return; }

  const chosen = values || (select.selectedIndex > 0 || select.options[0]?.defaultSelected ? [select.value] : []);
  select.multiple = true;
  Array.from(select.options).forEach((option) => { option.selected = chosen.includes(option.value); });
}

function additionalsSelectRowId(field) { return `tr_${field.replace('.', '_')}`; }

// Filter types of plugins are unknown to Redmine, it builds no select for them
function additionalsSelectEnsureSelect(row, field, values, multiple) {
  let select = row.querySelector('.values select.value');
  if (select) { return select; }

  const wrapper = document.createElement('span');
  wrapper.style.display = 'none';
  select = document.createElement('select');
  select.multiple = multiple;
  select.className = 'value';
  select.id = `values_${field.replace('.', '_')}_1`;
  select.name = `v[${field}][]`;
  (availableFilters[field].values || []).forEach((value) => {
    const [text, id] = Array.isArray(value) ? value : [value, value];
    select.append(new Option(text, id, false, values.includes(id)));
  });
  wrapper.append(select);
  row.querySelector('.values').append(wrapper);
  return select;
}

// "<< me >>" of a filter of users: a new filter (no values yet) takes it, as
// the select of core chooses its first value (the server offers it,
// QueryPatch), and the first choice of the user replaces it. A filter loaded
// with values (applied or saved) has chosen them, "<< me >>" included.
function additionalsSelectSuggestion(field, values) {
  if (values && values.length > 0) { return null; }

  const offered = (availableFilters[field].values || []).some((value) => Array.isArray(value) && value[1] === 'me');
  return offered ? 'me' : null;
}

function additionalsSelectFilterRow(field, values) {
  const options = additionalsSelectFilterOptions(field);
  if (!options) { return; }

  const row = document.getElementById(additionalsSelectRowId(field));
  if (!row || row.querySelector('[data-controller~="additionals-select"]')) { return; }

  const toggle = row.querySelector('.toggle-multiselect');
  if (toggle) { toggle.style.display = 'none'; }
  const multiple = options.multiple !== false;
  const select = additionalsSelectEnsureSelect(row, field, values || [], multiple);
  // the values of the filter, not what a single select chose by itself
  const suggestion = additionalsSelectSuggestion(field, values);
  if (multiple) { additionalsSelectMultiple(select, (values || []).map(String)); }
  if (suggestion) {
    Array.from(select.options).forEach((option) => { option.selected = option.value === suggestion; });
  } else if (!multiple && (!values || values.length === 0)) {
    // the browser chose its first option, the filter takes nothing nobody chose
    additionalsSelectSingle(select, []);
  }
  // the cell of a filter is as wide as its content: a share of it would
  // always lack that share and wrap the last chosen entry
  additionalsSelectApply(select, { width: 'auto', ...options, ...(suggestion ? { suggestion } : {}) });
}

/* Registers +options+ for filters (Ruby: additionals_select_filter). A filter
   type of a plugin gets the operators of an optional list. */
/* exported additionalsSelectRegisterFilter */
function additionalsSelectRegisterFilter(kind, name, options) {
  additionalsSelectFilters[kind][name] = options;
  if (kind === 'type' && typeof operatorByType !== 'undefined') {
    operatorByType[name] = operatorByType[name] || operatorByType.list_optional;
  }
}

/* Redmine empties the values of a filter it switches off (unchecked, operator
   without values) without telling anybody: the select field would still show
   the former values. It calls enableValues for each change of the operator,
   so only a field whose values it emptied is told. */
function additionalsSelectRowSelects(field) {
  return Array.from(document.querySelectorAll(
    `#${additionalsSelectRowId(field)} select[data-controller~="additionals-select"]`,
  ));
}

function additionalsSelectChosen(select) {
  return Array.from(select.selectedOptions, (option) => option.value).join('\n');
}

if (typeof enableValues === 'function' && !window.additionalsSelectEnableValuesWrapped) {
  window.additionalsSelectEnableValuesWrapped = true;
  const additionalsSelectEnableValues = enableValues;
  enableValues = function (field, indexes) {
    const selects = additionalsSelectRowSelects(field);
    const before = selects.map(additionalsSelectChosen);
    additionalsSelectEnableValues(field, indexes);
    selects.forEach((select, index) => {
      if (additionalsSelectChosen(select) !== before[index]) {
        select.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });
  };
}

if (typeof buildFilterRow === 'function' && !window.additionalsSelectFilterRowWrapped) {
  window.additionalsSelectFilterRowWrapped = true;
  const additionalsSelectBuildFilterRow = buildFilterRow;
  buildFilterRow = function (field, operator, values) {
    additionalsSelectBuildFilterRow(field, operator, values);
    additionalsSelectFilterRow(field, values);
  };
}

// The select fields of this page can be set up now
document.dispatchEvent(new Event('additionals-select:library-loaded'));
