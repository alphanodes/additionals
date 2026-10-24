import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import AdditionalsChartSettingsController from '../../../assets/javascripts/controllers/additionals_chart_settings_controller.js';

const SERIES_TYPES = ['bar_horizontal', 'bar_vertical', 'line', 'area', 'table'];

// The settings form as the server renders it, created_on is a date field
function form({ groupBy = 'status', chartType = 'doughnut', period = '', compare = '', split = '' } = {}) {
  const option = (value, selected) => `<option value="${value}"${value === selected ? ' selected' : ''}>${value}</option>`;
  const tile = (value) => `
    <label id="tile_${value}" data-additionals-chart-settings-target="tile">
      <input type="radio" name="chart_type" value="${value}"${value === chartType ? ' checked' : ''}
             data-additionals-chart-settings-target="chartType" data-action="change->additionals-chart-settings#update">
    </label>`;
  return `
    <form>
    <div data-controller="additionals-chart-settings"
         data-action="change->additionals-chart-settings#refreshSummary"
         data-additionals-chart-settings-summary-url-value="/dashboards/1/chart_summary?block=issue_chart"
         data-additionals-chart-settings-timeline-groups-value='["created_on"]'
         data-additionals-chart-settings-number-groups-value='["estimated_hours"]'
         data-additionals-chart-settings-timeline-types-value='${JSON.stringify([...SERIES_TYPES, 'calendar'])}'
         data-additionals-chart-settings-timeline-only-types-value='["line","area","calendar"]'
         data-additionals-chart-settings-series-types-value='${JSON.stringify(SERIES_TYPES)}'
         data-additionals-chart-settings-previous-period-value="previous"
         data-additionals-chart-settings-no-timeline-reason-value="Shows no timeline"
         data-additionals-chart-settings-timeline-only-reason-value="Only for a date field">
      <span id="summary" data-additionals-chart-settings-target="summary">Stored summary</span>
      <input id="title" name="settings[issue_chart][title]">
      <select id="group_by" name="settings[issue_chart][group_by]" data-additionals-chart-settings-target="groupBy"
              data-action="additionals-chart-settings#update">
        ${['status', 'created_on', 'estimated_hours'].map((value) => option(value, groupBy)).join('')}
      </select>
      <span id="interval" data-additionals-chart-settings-target="interval"></span>
      <span id="classes" data-additionals-chart-settings-target="classes"></span>
      <p id="split" data-additionals-chart-settings-target="series">
        <select id="split_select" data-additionals-chart-settings-target="splitSelect"
                data-action="additionals-chart-settings#update">
          ${['', 'tracker'].map((value) => option(value, split)).join('')}
        </select>
      </p>
      <p id="compare_field" data-additionals-chart-settings-target="series">
        <select id="compare" data-additionals-chart-settings-target="compareSelect">
          ${['', 'previous', '7'].map((value) => option(value, compare)).join('')}
        </select>
        <em id="compare_info" data-additionals-chart-settings-target="compareInfo"></em>
        <em id="compare_split_info" data-additionals-chart-settings-target="compareSplitInfo"></em>
      </p>
      <p id="shares_note" data-additionals-chart-settings-target="sharesNote"></p>
      ${['doughnut', 'pie', 'treemap', ...SERIES_TYPES, 'calendar'].map(tile).join('')}
      <p id="order" data-additionals-chart-settings-target="order"></p>
      <p id="max_entries" data-additionals-chart-settings-target="maxEntries"></p>
      <p id="show_empty" data-additionals-chart-settings-target="showEmpty"></p>
      <p data-additionals-chart-settings-target="withTable">
        <input type="hidden" id="with_table_hidden" name="settings[issue_chart][with_table]" value="0">
        <input type="checkbox" id="with_table" name="settings[issue_chart][with_table]" value="1" checked>
        <em id="with_table_info" data-additionals-chart-settings-target="withTableInfo"></em>
      </p>
      <select id="period_select" data-additionals-chart-settings-target="periodSelect"
              data-action="additionals-chart-settings#update">
        ${['', 'm', 'lm'].map((value) => option(value, period)).join('')}
      </select>
      <em id="period_info" data-additionals-chart-settings-target="periodInfo"></em>
    </div>
    </form>`;
}

// Stimulus connects controllers after a mutation of the document
function render(options) {
  document.body.innerHTML = form(options);
  return new Promise((resolve) => { setTimeout(resolve, 0); });
}

function element(id) {
  return document.getElementById(id);
}

function radios() {
  return Array.from(document.querySelectorAll('input[name="chart_type"]'));
}

function offeredTypes() {
  return radios().filter((radio) => !radio.disabled).map((radio) => radio.value);
}

function checkedType() {
  return radios().find((radio) => radio.checked)?.value;
}

function choose(id, value) {
  element(id).value = value;
  element(id).dispatchEvent(new Event('change'));
}

// A change as the browser reports it, bubbling up to the form
function change(id, value) {
  element(id).value = value;
  element(id).dispatchEvent(new Event('change', { bubbles: true }));
}

function waitForSummary() {
  return new Promise((resolve) => { setTimeout(resolve, 300); });
}

function mockSummary() {
  const fetchMock = vi.fn(() => Promise.resolve({
    ok: true,
    json: () => Promise.resolve({
      summary_html: 'Issues: Quantity over <span class="query-chart-summary-value">Created</span>',
      title: 'Issues » Created',
    }),
  }));
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

function chooseType(value) {
  const radio = radios().find((item) => item.value === value);
  radio.checked = true;
  radio.dispatchEvent(new Event('change'));
}

describe('AdditionalsChartSettingsController', () => {
  let application;

  beforeAll(() => {
    application = Application.start();
    application.register('additionals-chart-settings', AdditionalsChartSettingsController);
  });

  afterAll(() => {
    application.stop();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('hides the interval of a category', async () => {
    await render();

    expect(element('interval').hidden).toBe(true);
  });

  it('shows the interval of a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('interval').hidden).toBe(false);
  });

  it('offers no line and area for a category', async () => {
    await render();

    expect(offeredTypes()).toEqual(['doughnut', 'pie', 'treemap', 'bar_horizontal', 'bar_vertical', 'table']);
  });

  it('offers only types with series for a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(offeredTypes()).toEqual([...SERIES_TYPES, 'calendar']);
  });

  it('hides the interval of a calendar', async () => {
    await render({ groupBy: 'created_on', chartType: 'calendar' });

    expect(element('interval').hidden).toBe(true);
  });

  it('turns a doughnut into a line when a date field is chosen', async () => {
    await render();

    choose('group_by', 'created_on');

    expect(checkedType()).toBe('line');
  });

  it('turns a line into vertical bars when a category is chosen', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    choose('group_by', 'status');

    expect(checkedType()).toBe('bar_vertical');
  });

  it('keeps bars when a date field is chosen', async () => {
    await render({ chartType: 'bar_horizontal' });

    choose('group_by', 'created_on');

    expect(checkedType()).toBe('bar_horizontal');
  });

  it('hides the order of a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('order').hidden).toBe(true);
  });

  it('hides the bounds of a category', async () => {
    await render();

    expect(element('classes').hidden).toBe(true);
  });

  it('shows the bounds of a number field', async () => {
    await render({ groupBy: 'estimated_hours' });

    expect(element('classes').hidden).toBe(false);
  });

  it('hides the order of a number field', async () => {
    await render({ groupBy: 'estimated_hours' });

    expect(element('order').hidden).toBe(true);
  });

  it('hides the maximum of a number field', async () => {
    await render({ groupBy: 'estimated_hours' });

    expect(element('max_entries').hidden).toBe(true);
  });

  it('keeps entries without value for a number field', async () => {
    await render({ groupBy: 'estimated_hours' });

    expect(element('show_empty').hidden).toBe(false);
  });

  it('hides entries without value for a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('show_empty').hidden).toBe(true);
  });

  // Neither input is sent, the stored choice stays for other display types
  it('disables the table of values of a calendar and tells why', async () => {
    await render({ groupBy: 'created_on', chartType: 'calendar' });

    expect([element('with_table').disabled, element('with_table_hidden').disabled]).toEqual([true, true]);
    expect(element('with_table_info').hidden).toBe(false);
  });

  it('offers the table of values again for another display type', async () => {
    await render({ groupBy: 'created_on', chartType: 'calendar' });
    chooseType('line');

    expect([element('with_table').disabled, element('with_table_hidden').disabled]).toEqual([false, false]);
    expect(element('with_table_info').hidden).toBe(true);
  });

  it('disables the period of a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('period_select').disabled).toBe(true);
  });

  it('tells why the period of a date field is disabled', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('period_info').hidden).toBe(false);
  });

  it('hides the period hint of a category', async () => {
    await render();

    expect(element('period_info').hidden).toBe(true);
  });

  it('offers no previous period without a period', async () => {
    await render({ chartType: 'bar_vertical' });

    expect(element('compare').querySelector('option[value="previous"]').disabled).toBe(true);
  });

  it('offers the previous period when a period is chosen', async () => {
    await render({ chartType: 'bar_vertical' });

    choose('period_select', 'm');

    expect(element('compare').querySelector('option[value="previous"]').disabled).toBe(false);
  });

  it('drops the previous period when the period is removed', async () => {
    await render({ chartType: 'bar_vertical', period: 'm', compare: 'previous' });

    choose('period_select', '');

    expect(element('compare').value).toBe('');
  });

  it('hides split and comparison of a doughnut', async () => {
    await render();

    expect(element('split').hidden).toBe(true);
  });

  it('shows split and comparison when bars are chosen', async () => {
    await render();

    chooseType('bar_vertical');

    expect(element('split').hidden).toBe(false);
  });
  it('tells why split and comparison are missing for a doughnut', async () => {
    await render();

    expect(element('shares_note').hidden).toBe(false);
  });

  it('hides the shares hint for bars', async () => {
    await render({ chartType: 'bar_vertical' });

    expect(element('shares_note').hidden).toBe(true);
  });

  it('keeps types that do not fit visible but disabled', async () => {
    await render();

    expect(element('tile_line').classList.contains('disabled')).toBe(true);
  });

  it('names the reason of a disabled type of a category', async () => {
    await render();

    expect(element('tile_line').title).toBe('Only for a date field');
  });

  it('names the reason of a disabled type of a timeline', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('tile_doughnut').title).toBe('Shows no timeline');
  });

  it('gives a type that fits no reason', async () => {
    await render();

    expect(element('tile_bar_vertical').hasAttribute('title')).toBe(false);
  });

  it('marks the tile of the chosen type', async () => {
    await render();

    chooseType('bar_vertical');

    expect(element('tile_bar_vertical').classList.contains('selected')).toBe(true);
  });

  it('disables the comparison when a split is chosen', async () => {
    await render({ chartType: 'bar_vertical' });

    choose('split_select', 'tracker');

    expect(element('compare').disabled).toBe(true);
  });

  it('tells that the split replaces the comparison', async () => {
    await render({ chartType: 'bar_vertical', split: 'tracker' });

    expect([element('compare_info').hidden, element('compare_split_info').hidden]).toEqual([true, false]);
  });

  it('offers the comparison without a split', async () => {
    await render({ chartType: 'bar_vertical' });

    expect(element('compare').disabled).toBe(false);
  });

  it('asks the server for the summary of the changed form', async () => {
    const fetchMock = mockSummary();
    await render();

    change('group_by', 'created_on');
    await waitForSummary();

    expect(new URL(fetchMock.mock.calls[0][0], 'http://localhost').searchParams.get('settings[issue_chart][group_by]'))
      .toBe('created_on');
  });

  it('keeps the block of the summary url', async () => {
    const fetchMock = mockSummary();
    await render();

    change('group_by', 'created_on');
    await waitForSummary();

    expect(new URL(fetchMock.mock.calls[0][0], 'http://localhost').searchParams.get('block')).toBe('issue_chart');
  });

  it('shows the summary of the server', async () => {
    mockSummary();
    await render();

    change('group_by', 'created_on');
    await waitForSummary();

    expect(element('summary').textContent).toBe('Issues: Quantity over Created');
    expect(element('summary').querySelector('.query-chart-summary-value').textContent).toBe('Created');
  });

  it('offers the title of the server as placeholder', async () => {
    mockSummary();
    await render();

    change('group_by', 'created_on');
    await waitForSummary();

    expect(element('title').placeholder).toBe('Issues » Created');
  });

  it('asks the server once for several changes in a row', async () => {
    const fetchMock = mockSummary();
    await render();

    change('group_by', 'created_on');
    change('group_by', 'estimated_hours');
    await waitForSummary();

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('asks the server nothing before a change', async () => {
    const fetchMock = mockSummary();
    await render();
    await waitForSummary();

    expect(fetchMock).not.toHaveBeenCalled();
  });
});
