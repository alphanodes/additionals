/* global Chart */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import AdditionalsChartController, {
  chartConfig, renderTreemap, valueTicks, calendarConfig, calendarLevel, calendarLegend, calendarMonthLabels,
} from '../../../assets/javascripts/controllers/additionals_chart_controller.js';

function payload(overrides = {}) {
  return {
    type: 'doughnut',
    labels: ['Bug', 'Feature'],
    datasets: [{ label: 'Issues', data: [3, 1], urls: ['/issues?tracker=1', null] }],
    total: 4,
    totalLabel: 'Quantity',
    colorSchema: 'tableau.Classic20',
    ...overrides,
  };
}

// Context of the value label of the first bar, as chartjs-plugin-datalabels hands it over
function barContext(width) {
  return { datasetIndex: 0, dataIndex: 0, chart: { getDatasetMeta: () => ({ data: [{ width }] }) } };
}

// Bug split into New (3) and Closed (1), Feature into New (1)
function stackedPayload() {
  return payload({
    type: 'bar_horizontal',
    stacked: true,
    datasets: [
      { label: 'New', data: [3, 1], urls: [null, null] },
      { label: 'Closed', data: [1, 0], urls: [null, null] },
    ],
  });
}

// New and closed issues per month
function timelinePayload(type, stacked = false) {
  return payload({
    type,
    stacked,
    labels: ['Jan 2026', 'Feb 2026'],
    datasets: [
      { label: 'New', data: [3, 0], urls: ['/issues?jan=new', null] },
      { label: 'Closed', data: [1, 2], urls: ['/issues?jan=closed', null] },
    ],
  });
}

// Context of the value label of the first part of a stacked horizontal bar
function partContext(bar) {
  return {
    datasetIndex: 0,
    dataIndex: 0,
    dataset: { data: [3, 1] },
    chart: { getDatasetMeta: () => ({ data: [{ getProps: () => bar }] }) },
  };
}

// d3plus.Treemap is called with new and configured by chained calls. The mock
// keeps the argument of each call.
function mockTreemap() {
  const calls = {};
  class Treemap {
    render() {
      calls.render = true;
      return this;
    }
  }
  ['data', 'groupBy', 'sum', 'label', 'select', 'legend', 'zoom', 'search', 'tableView', 'on', 'tooltipConfig']
    .forEach((method) => {
      Treemap.prototype[method] = function chain(value) {
        calls[method] = value;
        return this;
      };
    });
  globalThis.d3plus = { Treemap };
  return calls;
}

let lastConfig = null;

function render(data) {
  lastConfig = chartConfig(document.createElement('canvas'), data);
}

function config() {
  return lastConfig;
}

describe('chart configuration', () => {
  beforeEach(() => {
    delete globalThis.d3plus;
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('draws a doughnut by default type', () => {
    render(payload());

    expect(config().type).toBe('doughnut');
  });

  it('shows the total in the middle of a doughnut', () => {
    render(payload());

    expect(config().options.plugins.annotation.annotations.total.content).toEqual(['4', 'Quantity']);
  });

  it('hides the legend of a pie with many slices', () => {
    const labels = Array.from({ length: 11 }, (_, index) => `Value ${index}`);
    render(payload({ labels, datasets: [{ label: 'Issues', data: labels.map(() => 1), urls: labels.map(() => null) }] }));

    expect(config().options.plugins.legend.display).toBe(false);
  });

  it('shows the formatted total in the middle of a doughnut', () => {
    render(payload({ totalText: '4:30' }));

    expect(config().options.plugins.annotation.annotations.total.content[0]).toBe('4:30');
  });

  it('shows formatted values in the tooltip', () => {
    render(payload({ valueTexts: [['3:00', '1:00']] }));

    const label = config().options.plugins.tooltip.callbacks.label({ label: 'Bug', raw: 3, dataIndex: 0 });

    expect(label).toBe('Bug: 3:00 (75%)');
  });

  it('draws a pie without a total in the middle', () => {
    render(payload({ type: 'pie' }));

    expect(config().options.plugins.annotation).toBeUndefined();
  });

  it('lays horizontal bars along the y axis', () => {
    render(payload({ type: 'bar_horizontal' }));

    expect(config().options.indexAxis).toBe('y');
  });

  it('lays vertical bars along the x axis', () => {
    render(payload({ type: 'bar_vertical' }));

    expect(config().options.indexAxis).toBe('x');
  });

  it('keeps room right of horizontal bars for the longest value', () => {
    render(payload({ type: 'bar_horizontal', valueTexts: [['2807:30', '1:00']] }));

    // 7 characters at 12px * 0.6 plus padding
    expect(config().options.layout.padding).toEqual({ right: 59 });
  });

  it('keeps room above vertical bars for slanted values', () => {
    render(payload({ type: 'bar_vertical', valueTexts: [['2807:30', '1:00']] }));

    // 51px text plus 12px font, slanted by 45 degrees, plus padding
    expect(config().options.layout.padding).toEqual({ top: 53 });
  });

  it('slants a value wider than its vertical bar', () => {
    render(payload({ type: 'bar_vertical', valueTexts: [['1346', '1']] }));

    const rotation = config().options.plugins.datalabels.rotation(barContext(10));

    expect(rotation).toBe(-45);
  });

  it('keeps a value level that fits on its vertical bar', () => {
    render(payload({ type: 'bar_vertical', valueTexts: [['1346', '1']] }));

    const rotation = config().options.plugins.datalabels.rotation(barContext(40));

    expect(rotation).toBe(0);
  });

  it('keeps values of horizontal bars level', () => {
    render(payload({ type: 'bar_horizontal', valueTexts: [['1346', '1']] }));

    const rotation = config().options.plugins.datalabels.rotation(barContext(10));

    expect(rotation).toBe(0);
  });

  it('places the legend of vertical bars below the chart', () => {
    render(payload({ type: 'bar_vertical' }));

    expect(config().options.plugins.legend.position).toBe('bottom');
  });

  it('hides the legend of a single series', () => {
    render(payload({ type: 'bar_vertical' }));

    expect(config().options.plugins.legend.display).toBe(false);
  });

  it('shows the legend of a comparison', () => {
    render(payload({
      type: 'bar_vertical',
      datasets: [{ label: 'Open', data: [3, 1] }, { label: 'This month', data: [2, 0] }],
    }));

    expect(config().options.plugins.legend.display).toBe(true);
  });

  it('opens the list of a clicked slice', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(payload());

    config().options.onClick({}, [{ datasetIndex: 0, index: 0 }]);

    expect(open).toHaveBeenCalledWith('/issues?tracker=1');
  });

  it('opens nothing for a slice without list', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(payload());

    config().options.onClick({}, [{ datasetIndex: 0, index: 1 }]);

    expect(open).not.toHaveBeenCalled();
  });

  it('opens the list of the comparison for a bar of the second series', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(payload({
      type: 'bar_vertical',
      datasets: [{ label: 'Open', data: [3, 1], urls: ['/issues?open=1', null] },
        { label: 'Bugs', data: [2, 0], urls: ['/issues?bugs=1', null] }],
    }));

    config().options.onClick({}, [{ datasetIndex: 1, index: 0 }]);

    expect(open).toHaveBeenCalledWith('/issues?bugs=1');
  });

  it('shows formatted values in the tooltip of a bar', () => {
    render(payload({ type: 'bar_vertical', valueTexts: [['3:00', '1:00']] }));

    const label = config().options.plugins.tooltip.callbacks.label({ dataset: { label: 'Hours' }, datasetIndex: 0, dataIndex: 0 });

    expect(label).toBe('Hours: 3:00');
  });

  it('stacks the parts of a split entry', () => {
    render(stackedPayload());

    expect([config().options.scales.x.stacked, config().options.scales.y.stacked]).toEqual([true, true]);
  });

  it('keeps the axis title of stacked bars', () => {
    render(stackedPayload());

    expect(config().options.scales.x.title.text).toBe('Quantity');
  });

  it('shows the share of a part in its entry in the tooltip', () => {
    render(stackedPayload());

    const label = config().options.plugins.tooltip.callbacks.label({
      dataset: { label: 'New' }, datasetIndex: 0, dataIndex: 0, raw: 3,
    });

    expect(label).toBe('New: 3 (75%)');
  });

  it('shows the value inside a part it fits in', () => {
    render(stackedPayload());

    const shown = config().options.plugins.datalabels.display(partContext({ x: 100, base: 0, height: 20 }));

    expect(shown).toBe(true);
  });

  it('hides the value of a part too small for it', () => {
    render(stackedPayload());

    const shown = config().options.plugins.datalabels.display(partContext({ x: 4, base: 0, height: 20 }));

    expect(shown).toBe(false);
  });

  it('draws a line chart for a line', () => {
    render(timelinePayload('line'));

    expect(config().type).toBe('line');
  });

  it('draws a line without area', () => {
    render(timelinePayload('line'));

    expect(config().data.datasets[0].fill).toBe(false);
  });

  it('fills an area down to the axis', () => {
    render(timelinePayload('area'));

    expect(config().data.datasets[0].fill).toBe('origin');
  });

  it('stacks the areas of a split', () => {
    render(timelinePayload('area', true));

    expect(config().data.datasets[1].fill).toBe('-1');
  });

  it('stacks the values of a split area', () => {
    render(timelinePayload('area', true));

    expect(config().options.scales.y.stacked).toBe(true);
  });

  it('shows the legend of a split line', () => {
    render(timelinePayload('line'));

    expect(config().options.plugins.legend.display).toBe(true);
  });

  it('opens the list of the line next to a click', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(timelinePayload('line'));
    const chart = { getElementsAtEventForMode: () => [{ datasetIndex: 1, index: 0 }] };

    config().options.onClick({ y: 50 }, [], chart);

    expect(open).toHaveBeenCalledWith('/issues?jan=closed');
  });

  // The upper area reaches from y 40 down to the line of the lower one at y 80
  it('opens the list of the stacked area a click lies in', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(timelinePayload('area', true));
    const chart = {
      getElementsAtEventForMode: () => [
        { datasetIndex: 1, index: 0, element: { y: 40 } },
        { datasetIndex: 0, index: 0, element: { y: 80 } },
      ],
    };

    config().options.onClick({ y: 60 }, [], chart);

    expect(open).toHaveBeenCalledWith('/issues?jan=closed');
  });

  it('opens nothing for a click above the stacked areas', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    render(timelinePayload('area', true));
    const chart = { getElementsAtEventForMode: () => [{ datasetIndex: 0, index: 0, element: { y: 80 } }] };

    config().options.onClick({ y: 20 }, [], chart);

    expect(open).not.toHaveBeenCalled();
  });

  it('draws no points on a long timeline', () => {
    render(payload({ type: 'line', labels: Array.from({ length: 61 }, (_v, index) => String(index)) }));

    expect(config().data.datasets[0].pointRadius).toBe(0);
  });

  it('draws a treemap with d3plus instead of Chart.js', () => {
    const calls = mockTreemap();
    renderTreemap(document.createElement('div'), payload({ type: 'treemap' }));

    expect(calls.render).toBe(true);
  });

  // d3plus fetches a data field named url as JSON, one request per tile
  it('hands the links to d3plus without a url field', () => {
    const calls = mockTreemap();
    renderTreemap(document.createElement('div'), payload({ type: 'treemap' }));

    expect(calls.data.some((tile) => 'url' in tile)).toBe(false);
  });

  // Two versions "1.0" of different projects must not become one tile
  it('keeps tiles with the same name apart', () => {
    const calls = mockTreemap();
    renderTreemap(document.createElement('div'), payload({ type: 'treemap' }));

    expect(calls.groupBy).toBe('id');
  });

  // d3plus writes its tooltip as HTML
  it('escapes the names in the tooltip of a treemap', () => {
    const calls = mockTreemap();
    renderTreemap(document.createElement('div'), payload({ type: 'treemap', labels: ['<img src=x onerror=alert(1)>', 'Feature'] }));

    expect(calls.tooltipConfig.title({ name: '<img src=x onerror=alert(1)>' })).toBe('&lt;img src=x onerror=alert(1)&gt;');
  });

  it('leaves out the untranslated share row of d3plus', () => {
    const calls = mockTreemap();
    renderTreemap(document.createElement('div'), payload({ type: 'treemap' }));

    expect(calls.tooltipConfig.tbody).toEqual([]);
  });
});

describe('value ticks', () => {
  it('counts in whole steps', () => {
    expect(valueTicks(payload({ datasets: [{ label: 'Issues', data: [0, 1, 2] }] }))).toEqual({ precision: 0 });
  });

  it('leaves decimals to Chart.js', () => {
    expect(valueTicks(payload({ datasets: [{ label: 'Hours', data: [0.5, 2] }] }))).toEqual({});
  });

  it('applies to the value axis of a timeline', () => {
    const { options } = chartConfig(null, payload({ type: 'area', datasets: [{ label: 'Pages', data: [0, 4] }] }));

    expect(options.scales.y.ticks).toEqual({ precision: 0 });
  });
});

// Seven pixels per character
function textWidth(text) {
  return text.length * 7;
}

// Axis of a calendar with a canvas that measures like textWidth
function calendarScale(width) {
  return {
    width,
    options: { ticks: { font: {} } },
    ctx: { save() {}, restore() {}, measureText: (text) => ({ width: textWidth(text) }) },
  };
}

// Two days of a calendar: Monday without, Tuesday with 3 entries
function calendarPayload() {
  return payload({
    type: 'calendar',
    labels: ['2026-04-06', '2026-04-07'],
    datasets: [{ label: 'Issues', data: [0, 3], urls: ['/issues?day=6', '/issues?day=7'] }],
    calendar: {
      points: [{ x: 0, y: 0, v: 0 }, { x: 0, y: 1, v: 3 }],
      weeks: 1,
      weekdays: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
      months: { 0: 'Apr' },
      levels: [1, 2, 5],
      legend: ['0', 'up to 1', 'up to 2', 'up to 5', 'above 5'],
    },
  });
}

describe('calendar', () => {
  beforeEach(() => {
    globalThis.Chart = {
      helpers: {
        color: () => ({ alpha: () => ({ rgbString: () => 'rgb(0, 0, 0)' }) }),
        toFont: () => ({ string: '12px sans-serif' }),
      },
    };
    window.Chart = globalThis.Chart;
  });

  it('puts a day without value on the lowest level', () => {
    expect(calendarLevel([1, 2, 5], 0)).toBe(0);
  });

  it('puts a value on the level of the first bound it does not exceed', () => {
    expect(calendarLevel([1, 2, 5], 3)).toBe(3);
  });

  it('puts a value above all bounds on the highest level', () => {
    expect(calendarLevel([1, 2, 5], 9)).toBe(4);
  });

  it('draws the days as cells of a matrix', () => {
    expect(calendarConfig(calendarPayload()).type).toBe('matrix');
  });

  it('names the rows by their weekday', () => {
    const { y } = calendarConfig(calendarPayload()).options.scales;

    expect(y.ticks.callback(1)).toBe('Tu');
  });

  it('names a column by the month that starts in it', () => {
    const { x } = calendarConfig(calendarPayload()).options.scales;
    const scale = calendarScale(100);

    x.afterBuildTicks(scale);

    expect(x.ticks.callback.call(scale, 0)).toBe('Apr');
  });

  it('names every month if there is room', () => {
    expect(calendarMonthLabels({ 0: 'Oct', 2: 'Nov', 6: 'Dec' }, 26, textWidth)).toEqual({ 0: 'Oct', 2: 'Nov', 6: 'Dec' });
  });

  it('leaves out the first month if the next one starts too close', () => {
    expect(calendarMonthLabels({ 0: 'Oct', 2: 'Nov', 6: 'Dec' }, 8, textWidth)).toEqual({ 2: 'Nov', 6: 'Dec' });
  });

  it('leaves out months that do not fit next to each other', () => {
    expect(calendarMonthLabels({ 0: 'Oct', 4: 'Nov', 8: 'Dec', 12: 'Jan' }, 4, textWidth)).toEqual({ 4: 'Nov', 12: 'Jan' });
  });

  it('keeps the latest month', () => {
    expect(calendarMonthLabels({ 0: 'Oct', 1: 'Nov' }, 4, textWidth)).toEqual({ 1: 'Nov' });
  });

  it('leaves out more of longer names', () => {
    expect(calendarMonthLabels({ 0: 'sept.', 4: 'oct.' }, 8, textWidth)).toEqual({ 4: 'oct.' });
  });

  it('opens the list of a clicked day', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);

    calendarConfig(calendarPayload()).options.onClick({}, [{ index: 1 }]);

    expect(open).toHaveBeenCalledWith('/issues?day=7');
  });

  it('shows a legend entry per level', () => {
    expect(calendarLegend(calendarPayload()).querySelectorAll('span')).toHaveLength(5);
  });
});

describe('AdditionalsChartController', () => {
  function controller(data, { canvas = true } = {}) {
    const element = document.createElement('div');
    element.id = 'query-chart-issue_chart';
    const target = canvas ? document.createElement('canvas') : null;
    if (target) {
      element.appendChild(target);
    }
    document.body.replaceChildren(element);
    // Stimulus defines element and the values as getters, the methods run on a plain context
    const { prototype } = AdditionalsChartController;
    const ctx = {
      element,
      payloadValue: data,
      hasCanvasTarget: Boolean(target),
      canvasTarget: target,
    };
    ctx.connect = prototype.connect.bind(ctx);
    ctx.disconnect = prototype.disconnect.bind(ctx);
    ctx.drawTreemap = prototype.drawTreemap.bind(ctx);
    ctx.drawCalendar = prototype.drawCalendar.bind(ctx);
    return ctx;
  }

  beforeEach(() => {
    globalThis.AdditionalsHelpers.loadLibrary = vi.fn(() => Promise.resolve());
    globalThis.Chart = vi.fn(function chart() {
      this.destroy = vi.fn();
    });
    delete globalThis.d3plus;
  });

  afterEach(() => {
    vi.restoreAllMocks();
    delete globalThis.Chart;
  });

  it('draws a Chart.js chart on its canvas', () => {
    const ctrl = controller(payload());
    ctrl.connect();

    expect(Chart.mock.calls[0][0]).toBe(ctrl.canvasTarget);
  });

  // A reloaded block replaces its element, the old chart must not stay registered
  it('releases its chart when the block goes away', () => {
    const ctrl = controller(payload());
    ctrl.connect();
    const { chart } = ctrl;
    ctrl.disconnect();

    expect(chart.destroy).toHaveBeenCalled();
  });

  it('reports a failed d3plus load in the console', async () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    AdditionalsHelpers.loadLibrary.mockReturnValue(Promise.reject(new Error('Could not load')));
    controller(payload({ type: 'treemap' }), { canvas: false }).connect();
    await new Promise((resolve) => { setTimeout(resolve, 0); });

    expect(error).toHaveBeenCalled();
  });

  it('draws nothing without a canvas', () => {
    controller(payload(), { canvas: false }).connect();

    expect(Chart).not.toHaveBeenCalled();
  });

  it('loads the matrix plugin for a calendar', () => {
    controller(calendarPayload()).connect();

    expect(AdditionalsHelpers.loadLibrary).toHaveBeenCalledWith('chartjs_matrix');
  });

  it('loads d3plus for a treemap', () => {
    mockTreemap();
    controller(payload({ type: 'treemap' }), { canvas: false }).connect();

    expect(AdditionalsHelpers.loadLibrary).toHaveBeenCalledWith('d3plus');
  });

  it('draws the treemap once d3plus is there', async () => {
    const calls = mockTreemap();
    await controller(payload({ type: 'treemap' }), { canvas: false }).drawTreemap(payload({ type: 'treemap' }));

    expect(calls.render).toBe(true);
  });

  // The block may be reloaded while d3plus is loading
  it('draws no treemap into a removed block', async () => {
    const calls = mockTreemap();
    const ctrl = controller(payload({ type: 'treemap' }), { canvas: false });
    ctrl.element.remove();
    await ctrl.drawTreemap(payload({ type: 'treemap' }));

    expect(calls.render).toBeUndefined();
  });
});
