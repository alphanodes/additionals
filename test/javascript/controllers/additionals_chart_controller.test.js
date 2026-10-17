/* global Chart */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import AdditionalsChartController, {
  chartConfig, renderTreemap, valueTicks, tooltipLine, withColors, shareDatasets, lineAnnotations, colorWithAlpha, areaGradient, legendLabels, schemeFill, markerTop, markerPlugin, matrixConfig, calendarConfig, calendarLevel, calendarLegend, calendarMonthLabels,
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

  it('hides the legend of a comparison on request', () => {
    render(payload({
      type: 'bar_horizontal',
      legend: false,
      datasets: [{ label: 'Used', data: [3, 1] }, { label: 'Available', data: [2, 0] }],
    }));

    expect(config().options.plugins.legend.display).toBe(false);
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

describe('burndown lines', () => {
  function burndownPayload(overrides = {}) {
    return payload({
      type: 'line',
      labels: ['1.6.', '2.6.', '3.6.'],
      points: false,
      datasets: [{ label: 'Open', data: [3, 2, null], fill: true },
        { label: 'Ideal', data: [3, 1.5, 0], style: 'dotted' }],
      ...overrides,
    });
  }

  it('dots a line of the style dotted', () => {
    expect(chartConfig(null, burndownPayload()).data.datasets[1].borderDash).toEqual([2, 3]);
  });

  it('fills a line on request', () => {
    expect(chartConfig(null, burndownPayload()).data.datasets[0].fill).toBe(true);
  });

  it('leaves the points out on request', () => {
    expect(chartConfig(null, burndownPayload()).data.datasets[0].pointRadius).toBe(0);
  });

  it('draws a line on top on request', () => {
    const { datasets } = chartConfig(null, burndownPayload({ datasets: [{ label: 'Open', data: [3, 2, null], fill: true },
      { label: 'Total', data: [3, 2, null], onTop: true }] })).data;

    expect(datasets.map((dataset) => dataset.order)).toEqual([0, -1]);
  });

  it('keeps the legend in the order of the payload', () => {
    const { sort } = chartConfig(null, burndownPayload()).options.plugins.legend.labels;

    expect([{ datasetIndex: 1 }, { datasetIndex: 0 }].sort(sort).map((item) => item.datasetIndex)).toEqual([0, 1]);
  });

  it('keeps the tooltip in the order of the payload', () => {
    const { itemSort } = chartConfig(null, burndownPayload()).options.plugins.tooltip;

    expect([{ datasetIndex: 1 }, { datasetIndex: 0 }].sort(itemSort).map((item) => item.datasetIndex)).toEqual([0, 1]);
  });

  it('fades a filled line out towards the axis', () => {
    expect(chartConfig(null, burndownPayload()).data.datasets[0].backgroundColor).toBe(areaGradient);
  });

  it('keeps stacked areas flat', () => {
    const { datasets } = chartConfig(null, burndownPayload({ stacked: true })).data;

    expect(datasets[0].backgroundColor).toBeUndefined();
  });

  it('keeps the gradient of a line with a color of its own', () => {
    const dataset = withColors(document.body, { data: [1], color: '--test-red', backgroundColor: areaGradient });

    expect(dataset.backgroundColor).toBe(areaGradient);
  });

  it('shows a point on hover of a line without points', () => {
    expect(chartConfig(null, burndownPayload()).data.datasets[0].pointHoverRadius).toBeGreaterThan(0);
  });

  it('draws the gradient in the color of the line', () => {
    const stops = [];
    const ctx = { createLinearGradient: () => ({ addColorStop: (offset, color) => stops.push(color) }) };

    areaGradient({ chart: { ctx, chartArea: { top: 0, bottom: 100 } }, dataset: { borderColor: '#ff0000' } });

    expect(stops).toEqual(['rgba(255, 0, 0, 0.35)', 'rgba(255, 0, 0, 0.02)']);
  });

  it('draws no gradient before the first layout', () => {
    expect(areaGradient({ chart: { ctx: null }, dataset: { borderColor: '#ff0000' } })).toBe('rgba(0, 0, 0, 0)');
  });

  it('shows a faded line in the legend in its top color', () => {
    const generateLabels = () => [{ datasetIndex: 0, strokeStyle: '#ff0000', fillStyle: 'rgba(0, 0, 0, 0)' }];
    globalThis.Chart = { defaults: { plugins: { legend: { labels: { generateLabels } } } } };

    expect(legendLabels({ data: { datasets: [{ backgroundColor: areaGradient }] } })[0].fillStyle)
      .toBe('rgba(255, 0, 0, 0.35)');
  });

  it('adds an opacity to short hex, long hex and rgb colors', () => {
    expect(['#f00', '#ff0000', 'rgb(255, 0, 0)'].map((color) => colorWithAlpha(color, 0.5)))
      .toEqual(Array(3).fill('rgba(255, 0, 0, 0.5)'));
  });

  it('marks a line across the chart at its value', () => {
    const lines = lineAnnotations(document.body, burndownPayload({ lines: [{ axis: 'x', value: 1.5, label: 'Today' }] }));

    expect([lines.line0.xMin, lines.line0.label.content]).toEqual([1.5, 'Today']);
  });

  it('puts the text of a line across the values on the right', () => {
    const lines = lineAnnotations(document.body, burndownPayload({ lines: [{ axis: 'y', value: 2, label: 'Average' }] }));

    expect(lines.line0.label.position).toBe('end');
  });

  it('adds the lines to the annotations of the chart', () => {
    const { options } = chartConfig(document.body, burndownPayload({ lines: [{ axis: 'x', value: 1, label: 'Today' }] }));

    expect(Object.keys(options.plugins.annotation.annotations)).toEqual(['line0']);
  });
});

describe('bars with lines and markers', () => {
  function revenuePayload(overrides = {}) {
    return payload({
      type: 'bar_vertical',
      stacked: true,
      labels: ['Jan', 'Feb'],
      datasets: [{ label: 'Paid', data: [10, 20], markers: ['worst', 'best'] },
        { label: 'Sent', data: [5, 0] },
        { label: '2025', data: [12, 18], type: 'line', style: 'dashed' }],
      ...overrides,
    });
  }

  function labelContext(revenueConfig, datasetIndex) {
    return { dataset: revenueConfig.data.datasets[datasetIndex], dataIndex: 0, datasetIndex };
  }

  it('lays a line over the bars in a stack of its own', () => {
    const line = chartConfig(document.body, revenuePayload()).data.datasets[2];

    expect([line.stack, line.order, line.borderDash]).toEqual(['line', -1, [6, 4]]);
  });

  it('keeps the line in its place of the payload in the legend', () => {
    const { sort } = chartConfig(document.body, revenuePayload()).options.plugins.legend.labels;

    expect([{ datasetIndex: 2 }, { datasetIndex: 0 }].sort(sort).map((item) => item.datasetIndex)).toEqual([0, 2]);
  });

  it('colors the points of a line with a color of its own', () => {
    const dataset = withColors(document.body, { data: [1], color: '--test-red', type: 'line' });

    expect(dataset.pointBackgroundColor).toBe(dataset.borderColor);
  });

  it('keeps the line in its place of the payload in the tooltip', () => {
    const { itemSort } = chartConfig(document.body, revenuePayload()).options.plugins.tooltip;

    expect([{ datasetIndex: 2 }, { datasetIndex: 0 }].sort(itemSort).map((item) => item.datasetIndex)).toEqual([0, 2]);
  });

  it('shows no value label on a line', () => {
    const revenueConfig = chartConfig(document.body, revenuePayload({ stacked: false }));

    expect(revenueConfig.options.plugins.datalabels.display(labelContext(revenueConfig, 2))).toBe(false);
  });

  it('shows no value labels on request', () => {
    const revenueConfig = chartConfig(document.body, revenuePayload({ stacked: false, valueLabels: false }));

    expect(revenueConfig.options.plugins.datalabels.display(labelContext(revenueConfig, 0))).toBe(false);
  });

  it('leaves the line out of the share of a part', () => {
    const revenueConfig = chartConfig(document.body, revenuePayload());
    const label = revenueConfig.options.plugins.tooltip.callbacks.label(labelContext(revenueConfig, 0));

    expect(label).toBe('Paid: 10 (67%)');
  });

  it('shows no share of the stack for a line', () => {
    const revenueConfig = chartConfig(document.body, revenuePayload());

    expect(revenueConfig.options.plugins.tooltip.callbacks.label(labelContext(revenueConfig, 2))).toBe('2025: 12');
  });

  it('names the meaning of a marker in the tooltip of stacked bars', () => {
    const revenueConfig = chartConfig(document.body, revenuePayload());

    expect(revenueConfig.options.plugins.tooltip.callbacks.afterLabel({ dataset: { tooltips: ['Worst month'] }, dataIndex: 0 }))
      .toBe('Worst month');
  });

  it('opens the tooltip for the whole column of a marked period', () => {
    expect(chartConfig(document.body, revenuePayload()).options.interaction).toEqual({ mode: 'index', intersect: false });
  });

  it('leaves the empty parts out of the tooltip of a column', () => {
    const { filter } = chartConfig(document.body, revenuePayload()).options.plugins.tooltip;

    expect([filter({ dataset: {}, raw: 0, dataIndex: 0 }), filter({ dataset: { type: 'line' }, raw: 0, dataIndex: 0 })])
      .toEqual([false, true]);
  });

  it('keeps an empty part carrying a marker in the tooltip', () => {
    const { filter } = chartConfig(document.body, revenuePayload()).options.plugins.tooltip;

    expect(filter({ dataset: { markers: ['worst'] }, raw: 0, dataIndex: 0 })).toBe(true);
  });

  it('opens the list of the bar under the pointer', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    const payloadWithUrls = revenuePayload({ datasets: [{ label: 'Paid', data: [10], urls: ['/paid'], markers: ['best'] }, { label: 'Sent', data: [5], urls: ['/sent'] }] });
    const chart = { getElementsAtEventForMode: () => [{ datasetIndex: 1, index: 0 }] };

    chartConfig(document.body, payloadWithUrls).options.onClick({}, [{ datasetIndex: 0, index: 0 }], chart);

    expect(open).toHaveBeenCalledWith('/sent');
    open.mockRestore();
  });

  it('makes room above the bars for markers', () => {
    expect(chartConfig(document.body, revenuePayload()).options.layout.padding.top).toBeGreaterThan(0);
  });

  it('draws the markers with a plugin of its own', () => {
    const ids = chartConfig(document.body, revenuePayload()).plugins.map((plugin) => plugin.id);

    expect(ids).toContain('additionalsMarkers');
  });

  it('puts a marker on top of the whole stack', () => {
    const bars = [[{ y: 80, base: 100 }], [{ y: 60, base: 80 }], [{ y: 10, base: 100 }]];
    const chart = {
      data: { datasets: [{ stack: undefined }, { stack: undefined }, { type: 'line', stack: 'line' }] },
      options: { scales: { y: { stacked: true } } },
      isDatasetVisible: () => true,
      getDatasetMeta: (index) => ({ data: bars[index] }),
    };

    expect(markerTop(chart, 0, 0)).toBe(60);
  });

  it('draws the glyph of a marker above its bar', () => {
    const texts = [];
    const chart = {
      ctx: {
        save() {}, restore() {}, fillText: (text, x, y) => texts.push([text, x, y]),
      },
      data: { datasets: [{ markers: ['best'] }] },
      options: { scales: { y: {} } },
      isDatasetVisible: () => true,
      getDatasetMeta: () => ({ data: [{ x: 30, y: 50, base: 100 }] }),
    };

    markerPlugin(document.body).afterDatasetsDraw(chart);

    expect(texts).toEqual([['★', 30, 46]]);
  });
});

// A canvas with CSS custom properties, as the page provides them
function canvasWith(colors) {
  const canvas = document.createElement('canvas');
  Object.entries(colors).forEach(([name, value]) => canvas.style.setProperty(name, value));
  document.body.append(canvas);
  return canvas;
}

describe('matrix', () => {
  function matrixPayload() {
    return payload({
      type: 'matrix',
      matrix: {
        columns: ['Mon', 'Tue'],
        rows: ['Anna', 'Ben'],
        cells: [{
          x: 'Mon', y: 'Anna', color: '--test-red', title: 'Anna - Monday', lines: ['Booked: 2 h'], url: '/anna',
        }],
      },
    });
  }

  it('colors a cell in the color of its category', () => {
    const canvas = canvasWith({ '--test-red': 'rgb(250, 82, 82)' });
    const { backgroundColor } = matrixConfig(canvas, matrixPayload()).data.datasets[0];

    expect(backgroundColor({ raw: matrixPayload().matrix.cells[0] })).toBe('rgb(250, 82, 82)');
  });

  it('shows the first row on top', () => {
    expect(matrixConfig(document.body, matrixPayload()).options.scales.y.labels).toEqual(['Ben', 'Anna']);
  });

  it('names a cell and its values in the tooltip', () => {
    const { callbacks } = matrixConfig(document.body, matrixPayload()).options.plugins.tooltip;
    const cell = matrixPayload().matrix.cells[0];

    expect([callbacks.title([{ raw: cell }]), callbacks.label({ raw: cell })]).toEqual(['Anna - Monday', ['Booked: 2 h']]);
  });

  it('opens the link of a clicked cell', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);

    matrixConfig(document.body, matrixPayload()).options.onClick({}, [{ index: 0 }]);

    expect(open).toHaveBeenCalledWith('/anna');
    open.mockRestore();
  });
});

describe('stacked as shares', () => {
  function sharePayload() {
    return payload({
      type: 'bar_vertical',
      labels: ['open', 'closed'],
      stacked: true,
      percent: true,
      datasets: [{ label: 'Estimated', data: [1, 30] }, { label: 'Not estimated', data: [3, 70] }],
    });
  }

  it('turns the parts into shares of their bar', () => {
    expect(shareDatasets(sharePayload())[0].data).toEqual([25, 30]);
  });

  it('ends the value axis at 100 %', () => {
    expect(chartConfig(null, sharePayload()).options.scales.y.max).toBe(100);
  });

  it('names the count and the share in the tooltip', () => {
    const { options } = chartConfig(null, sharePayload());
    const label = options.plugins.tooltip.callbacks.label({
      dataset: { label: 'Estimated' }, datasetIndex: 0, dataIndex: 0, raw: 25,
    });

    expect(label).toBe('Estimated: 1 (25%)');
  });
});

describe('fixed colors', () => {
  it('reads a color per point from its CSS custom property', () => {
    const canvas = canvasWith({ '--test-red': 'rgb(250, 82, 82)' });

    expect(withColors(canvas, { data: [1], colors: ['--test-red'] }).backgroundColor).toEqual(['rgb(250, 82, 82)']);
  });

  it('leaves a dataset without colors to the color scheme', () => {
    const dataset = { data: [1] };

    expect(withColors(null, dataset)).toBe(dataset);
  });

  it('applies to the slices of a pie', () => {
    const canvas = canvasWith({ '--test-green': 'rgb(64, 192, 87)' });
    const { data } = chartConfig(canvas, payload({ type: 'pie', datasets: [{ label: 'Issues', data: [3], colors: ['--test-green'] }] }));

    expect(data.datasets[0].backgroundColor).toEqual(['rgb(64, 192, 87)']);
  });

  it('keeps the color of the scheme for a point without one', () => {
    const canvas = canvasWith({ '--test-red': 'rgb(250, 82, 82)' });
    const dataset = withColors(canvas, { data: [1, 2], colors: ['--test-red', null] }, () => 'scheme');

    expect(dataset.backgroundColor).toEqual(['rgb(250, 82, 82)', 'scheme']);
  });
});

describe('scheme fill', () => {
  beforeEach(() => {
    window.Chart = { colorschemes: { test: { three: ['#ff0000', '#00ff00', '#0000ff'] } } };
  });

  afterEach(() => {
    delete window.Chart;
  });

  it('fills a bar in the color of its dataset with the alpha of bars', () => {
    expect(schemeFill(payload({ type: 'bar_horizontal', colorSchema: 'test.three' }), 1, 0)).toBe('rgba(0, 255, 0, 0.8)');
  });

  it('fills a slice of a pie in the color of the slice', () => {
    expect(schemeFill(payload({ type: 'pie', colorSchema: 'test.three' }), 0, 4)).toBe('#00ff00');
  });

  it('leaves the color open without a known scheme', () => {
    expect(schemeFill(payload({ type: 'pie', colorSchema: 'unknown.scheme' }), 0, 0)).toBeNull();
  });
});

describe('tooltip line', () => {
  it('shows the line of a point', () => {
    expect(tooltipLine({ dataset: { tooltips: ['closed: 3', 'closed: 5'] }, dataIndex: 1 })).toBe('closed: 5');
  });

  it('shows nothing without lines', () => {
    expect(tooltipLine({ dataset: {}, dataIndex: 0 })).toBe('');
  });

  it('applies to the tooltip of a timeline', () => {
    const { options } = chartConfig(null, payload({ type: 'line' }));

    expect(options.plugins.tooltip.callbacks.afterLabel).toBe(tooltipLine);
  });

  it('applies to the tooltip of bars', () => {
    const { options } = chartConfig(null, payload({ type: 'bar_vertical' }));

    expect(options.plugins.tooltip.callbacks.afterLabel).toBe(tooltipLine);
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
    ctx.drawWithLines = prototype.drawWithLines.bind(ctx);
    ctx.drawMatrix = prototype.drawMatrix.bind(ctx);
    return ctx;
  }

  beforeEach(() => {
    globalThis.AdditionalsHelpers.loadLibrary = vi.fn(() => Promise.resolve());
    globalThis.Chart = vi.fn(function chart() {
      this.destroy = vi.fn();
    });
    // The legend of a calendar colors its levels
    globalThis.Chart.helpers = { color: () => ({ alpha: () => ({ rgbString: () => 'rgb(0, 0, 0)' }) }) };
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

  it('loads the annotation plugin for lines across the chart', () => {
    controller(payload({ type: 'line', lines: [{ axis: 'x', value: 1, label: 'Today' }] })).connect();

    expect(AdditionalsHelpers.loadLibrary).toHaveBeenCalledWith('chartjs_annotation');
  });

  it('loads the matrix plugin for a matrix', () => {
    controller(payload({ type: 'matrix', matrix: { columns: [], rows: [], cells: [] } })).connect();

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
