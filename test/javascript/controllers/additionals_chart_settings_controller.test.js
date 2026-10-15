import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Application } from '@hotwired/stimulus';
import AdditionalsChartSettingsController from '../../../assets/javascripts/controllers/additionals_chart_settings_controller.js';

const SERIES_TYPES = ['bar_horizontal', 'bar_vertical', 'line', 'area', 'table'];

// The settings form as the server renders it, created_on is a date field
function form({ groupBy = 'status', chartType = 'doughnut', period = '', compare = '' } = {}) {
  const option = (value, selected) => `<option value="${value}"${value === selected ? ' selected' : ''}>${value}</option>`;
  return `
    <div data-controller="additionals-chart-settings"
         data-additionals-chart-settings-timeline-groups-value='["created_on"]'
         data-additionals-chart-settings-number-groups-value='["estimated_hours"]'
         data-additionals-chart-settings-line-types-value='["line","area"]'
         data-additionals-chart-settings-series-types-value='${JSON.stringify(SERIES_TYPES)}'
         data-additionals-chart-settings-previous-period-value="previous">
      <select id="group_by" data-additionals-chart-settings-target="groupBy"
              data-action="additionals-chart-settings#update">
        ${['status', 'created_on', 'estimated_hours'].map((value) => option(value, groupBy)).join('')}
      </select>
      <span id="interval" data-additionals-chart-settings-target="interval"></span>
      <span id="classes" data-additionals-chart-settings-target="classes"></span>
      <p id="split" data-additionals-chart-settings-target="series"></p>
      <select id="chart_type" data-additionals-chart-settings-target="chartType"
              data-action="additionals-chart-settings#update">
        ${['doughnut', 'pie', 'treemap', ...SERIES_TYPES].map((value) => option(value, chartType)).join('')}
      </select>
      <p id="order" data-additionals-chart-settings-target="order"></p>
      <p id="max_entries" data-additionals-chart-settings-target="maxEntries"></p>
      <p id="show_empty" data-additionals-chart-settings-target="showEmpty"></p>
      <p id="period" data-additionals-chart-settings-target="period">
        <select id="period_select" data-additionals-chart-settings-target="periodSelect"
                data-action="additionals-chart-settings#update">
          ${['', 'm', 'lm'].map((value) => option(value, period)).join('')}
        </select>
      </p>
      <select id="compare" data-additionals-chart-settings-target="compareSelect">
        ${['', 'previous', '7'].map((value) => option(value, compare)).join('')}
      </select>
    </div>`;
}

// Stimulus connects controllers after a mutation of the document
function render(options) {
  document.body.innerHTML = form(options);
  return new Promise((resolve) => { setTimeout(resolve, 0); });
}

function element(id) {
  return document.getElementById(id);
}

function offeredTypes() {
  return Array.from(element('chart_type').options).filter((option) => !option.disabled).map((option) => option.value);
}

function choose(id, value) {
  element(id).value = value;
  element(id).dispatchEvent(new Event('change'));
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

    expect(offeredTypes()).toEqual(SERIES_TYPES);
  });

  it('turns a doughnut into a line when a date field is chosen', async () => {
    await render();

    choose('group_by', 'created_on');

    expect(element('chart_type').value).toBe('line');
  });

  it('turns a line into vertical bars when a category is chosen', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    choose('group_by', 'status');

    expect(element('chart_type').value).toBe('bar_vertical');
  });

  it('keeps bars when a date field is chosen', async () => {
    await render({ chartType: 'bar_horizontal' });

    choose('group_by', 'created_on');

    expect(element('chart_type').value).toBe('bar_horizontal');
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

  it('hides the period of a date field', async () => {
    await render({ groupBy: 'created_on', chartType: 'line' });

    expect(element('period').hidden).toBe(true);
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

    choose('chart_type', 'bar_vertical');

    expect(element('split').hidden).toBe(false);
  });
});
