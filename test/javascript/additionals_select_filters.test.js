/* global additionalsSelectRegisterFilter, additionalsSelectApply, buildFilterRow, enableValues */
import { describe, it, expect, beforeAll, beforeEach, vi } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Redmine core builds the row of a filter, with a select for list types only
function coreBuildFilterRow(field) {
  const filter = globalThis.availableFilters[field];
  const select = filter.type === 'list'
    ? `<select class="value" id="values_${field}_1" name="v[${field}][]"><option value="1">One</option></select>`
    : '';
  document.getElementById('filters-table').insertAdjacentHTML('beforeend', `
    <tr id="tr_${field.replace('.', '_')}"><td class="values">${select}<span class="toggle-multiselect"></span></td></tr>`);
}

const filtersScript = readFileSync(resolve(__dirname, '../../assets/javascripts/additionals_select_filters.js'), 'utf-8');
const globalEval = eval; // eslint-disable-line no-eval

beforeAll(() => {
  globalThis.availableFilters = {};
  globalThis.operatorByType = { list_optional: ['=', '!', '!*', '*'] };
  globalThis.buildFilterRow = (field) => coreBuildFilterRow(field);
  // Redmine core empties the values of a filter it switches off
  globalThis.enableValues = (field, indexes) => {
    document.querySelectorAll(`#tr_${field.replace('.', '_')} .values .value`).forEach((element, index) => {
      if (!indexes.includes(index)) { element.value = ''; }
    });
  };

  globalEval(filtersScript);
});

beforeEach(() => {
  document.body.innerHTML = '<table><tbody id="filters-table"></tbody></table>';
  window.additionalsSelectFilters.type = {};
  window.additionalsSelectFilters.fieldFormat = {};
  window.additionalsSelectFilters.field = {};
  globalThis.availableFilters = {
    author_id: { type: 'author', values: [['John Smith', '2'], ['Jane', '3']] },
    cf_1: { type: 'list', field_format: 'db_entry', values: [] },
    status_id: { type: 'list', values: [['New', '1']] },
  };
});

const select = (field) => document.querySelector(`#tr_${field} select.value`);

describe('additionals_select_filters.js', () => {
  it('gives a filter type of a plugin the operators of an optional list', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users' });

    expect(globalThis.operatorByType.author).toEqual(['=', '!', '!*', '*']);
  });

  it('builds a select field for a filter type Redmine knows no select for', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users?a=1&b=2', minInputLength: 1 });
    buildFilterRow('author_id', '=', ['2']);

    const field = select('author_id');

    expect([field.name, field.multiple, field.dataset.controller]).toEqual(['v[author_id][]', true, 'additionals-select']);
    expect([field.dataset.additionalsSelectUrlValue, field.dataset.additionalsSelectMinInputLengthValue])
      .toEqual(['/users?a=1&b=2', '1']);
    expect(Array.from(field.selectedOptions).map((option) => option.text)).toEqual(['John Smith']);
  });

  // a share of a cell that is as wide as its content would always lack that
  // share and put the last chosen entry onto a line of its own
  it('makes a field of a filter row as wide as its entries unless the registration sets a width', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users' });
    additionalsSelectRegisterFilter('fieldFormat', 'db_entry', { url: '/entries', width: '50%' });
    buildFilterRow('author_id', '=', ['2']);
    buildFilterRow('cf_1', '=', []);

    expect([select('author_id').dataset.additionalsSelectWidthValue, select('cf_1').dataset.additionalsSelectWidthValue])
      .toEqual(['auto', '50%']);
  });

  it('uses the select Redmine built and hides its multiple toggle', () => {
    additionalsSelectRegisterFilter('fieldFormat', 'db_entry', { url: '/entries' });
    buildFilterRow('cf_1', '=', []);

    expect(document.querySelectorAll('#tr_cf_1 select')).toHaveLength(1);
    expect(select('cf_1').dataset.additionalsSelectUrlValue).toBe('/entries');
    expect(document.querySelector('#tr_cf_1 .toggle-multiselect').style.display).toBe('none');
  });

  it('prefers the field name over its field format and its type', () => {
    additionalsSelectRegisterFilter('type', 'list', { url: '/type' });
    additionalsSelectRegisterFilter('fieldFormat', 'db_entry', { url: '/format' });
    additionalsSelectRegisterFilter('field', 'cf_1', { url: '/field' });
    buildFilterRow('cf_1', '=', []);
    buildFilterRow('status_id', '=', []);

    expect([select('cf_1').dataset.additionalsSelectUrlValue, select('status_id').dataset.additionalsSelectUrlValue])
      .toEqual(['/field', '/type']);
  });

  it('keeps a single select where the filter takes one value', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users', multiple: false });
    buildFilterRow('author_id', '=', []);

    expect(select('author_id').multiple).toBe(false);
  });

  // a select of the browser has its first option chosen, the filter would
  // take a value nobody chose (e.g. a project of an action of automation)
  it('chooses nothing in a single select without a value of the filter', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users', multiple: false });
    additionalsSelectRegisterFilter('type', 'list', { url: '/statuses', multiple: false });
    buildFilterRow('author_id', '=', []);
    buildFilterRow('status_id', '=', ['1']);

    expect([select('author_id').value, select('status_id').value]).toEqual(['', '1']);
  });

  it('chooses nothing by itself when the filter has no values yet', () => {
    additionalsSelectRegisterFilter('type', 'author', { url: '/users' });
    additionalsSelectRegisterFilter('type', 'list', { url: '/statuses' });
    buildFilterRow('author_id', '=', []);
    buildFilterRow('status_id', '=', []);

    expect(Array.from(select('author_id').selectedOptions)).toEqual([]);
    expect(Array.from(select('status_id').selectedOptions)).toEqual([]);
  });

  it('keeps the values of the filter in a select Redmine built', () => {
    additionalsSelectRegisterFilter('type', 'list', { url: '/statuses' });
    buildFilterRow('status_id', '=', ['1']);

    expect(Array.from(select('status_id').selectedOptions).map((option) => option.value)).toEqual(['1']);
  });

  it('can be loaded again by content that comes later', () => {
    const wrapped = globalThis.buildFilterRow;
    const loaded = vi.fn();
    document.addEventListener('additionals-select:library-loaded', loaded);

    expect(() => globalEval(filtersScript)).not.toThrow();
    expect(globalThis.buildFilterRow).toBe(wrapped);
    expect(loaded).toHaveBeenCalledTimes(1);
    document.removeEventListener('additionals-select:library-loaded', loaded);
  });

  it('shows the emptied value when Redmine switches the values of a filter off', () => {
    additionalsSelectRegisterFilter('type', 'list', { url: '/statuses' });
    buildFilterRow('status_id', '=', ['1']);
    const changed = vi.fn();
    select('status_id').addEventListener('change', changed);

    enableValues('status_id', []);

    expect(changed).toHaveBeenCalledTimes(1);
  });

  it('keeps the first option when it is the value given to additionalsSelectApply', () => {
    document.body.innerHTML = '<select><option value="1">One</option><option value="2">Two</option></select>';
    const field = document.querySelector('select');
    field.value = '1';

    additionalsSelectApply(field, { url: '/entries', values: ['1'] });

    expect(Array.from(field.selectedOptions).map((option) => option.value)).toEqual(['1']);
  });

  it('leaves filters without registration as Redmine built them', () => {
    buildFilterRow('status_id', '=', []);

    expect(select('status_id').dataset.controller).toBeUndefined();
  });
});
