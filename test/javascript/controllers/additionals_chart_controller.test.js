/* global Chart */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import AdditionalsChartController, {
  chartConfig, treemapConfig, treemapTiles, treemapLabelLayout, contrastingText, percentText, sankeyConfig, sankeyNodeAt, valueTicks, tooltipLine, withColors, shareDatasets, lineAnnotations, colorWithAlpha, areaGradient, legendLabels, schemeFill, pageLocale, formatNumber, markerTop, markerPlugin, matrixConfig, calendarConfig, calendarLevel, calendarLegend, calendarMonthLabels,
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

// Projects with A and B, A with C and D
function sankeyPayload() {
  return {
    type: 'sankey',
    sankey: {
      nodes: [{ id: 'root', name: 'Projects' }, { id: 'a', name: '<b>A</b>', url: '/projects/a' },
        { id: 'b', name: 'B', url: '/projects/b' }, { id: 'c', name: 'C', url: '/projects/c' }, { id: 'd', name: 'D', url: '/projects/d' }],
      links: [{ source: 'root', target: 'a' }, { source: 'root', target: 'b' }, { source: 'a', target: 'c' }, { source: 'a', target: 'd' }],
    },
  };
}

// A drawn sankey of the payload: each flow 50 high, its source node ends at
// x, its target node starts at x2
function sankeyChart(sankey, elementsAt = () => []) {
  const places = [[10, 100, 0, 0], [10, 100, 100, 100], [110, 200, 0, 0], [110, 200, 50, 50]];
  return {
    data: sankey.data,
    canvas: document.createElement('canvas'),
    getElementsAtEventForMode: elementsAt,
    getDatasetMeta: () => ({
      data: places.map(([x, x2, y, y2]) => ({ getProps: () => ({ x, x2, y, y2, height: 50 }) })),
    }),
  };
}

let lastConfig = null;

function render(data) {
  lastConfig = chartConfig(document.createElement('canvas'), data);
}

function config() {
  return lastConfig;
}

describe('chart configuration', () => {
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

  // Days as lines on the left, a count as bars on the right
  function secondaryPayload() {
    return payload({
      type: 'bar_vertical',
      labels: ['Sep', 'Oct'],
      secondaryLabel: 'Issues',
      totalLabel: 'Days',
      datasets: [{ label: 'Median', type: 'line', data: [2.5, null] },
        { label: 'Closed', axis: 'secondary', data: [12, 0] }],
    });
  }

  it('puts a series of another unit on an axis on the right', () => {
    render(secondaryPayload());

    expect(config().data.datasets.map((dataset) => dataset.yAxisID)).toEqual([undefined, 'y1']);
    expect(config().options.scales.y1).toMatchObject({ position: 'right', title: { display: true, text: 'Issues' } });
    // Its lines across the chart would cross the ones of the left axis
    expect(config().options.scales.y1.grid.drawOnChartArea).toBe(false);
  });

  it('counts the ticks of each axis by its own values', () => {
    render(secondaryPayload());

    expect([config().options.scales.y.ticks.precision, config().options.scales.y1.ticks.precision]).toEqual([undefined, 0]);
  });

  it('keeps one value axis without a series of another unit', () => {
    render(payload({ type: 'bar_vertical' }));

    expect(config().options.scales.y1).toBeUndefined();
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

  it('hides the legend of a split line on request', () => {
    render({ ...timelinePayload('line'), legend: false });

    expect(config().options.plugins.legend.display).toBe(false);
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

  it('draws a treemap with the treemap plugin of Chart.js', () => {
    const treemap = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' }));

    expect([treemap.type, treemap.data.datasets[0].key]).toEqual(['treemap', 'value']);
  });

  it('writes the name bold at the top left and the share smaller below it', () => {
    // jsdom measures no text, every character is half its font size wide
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue({
      font: '12px sans-serif',
      measureText(text) { return { width: text.length * Number.parseInt(this.font.match(/(\d+)px/)[1], 10) * 0.5 }; },
    });
    const { labels } = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' })).data.datasets[0];
    const context = { dataIndex: 0, raw: { w: 400, h: 300, v: 3, _data: { tile: 'Bug' } } };
    const fonts = labels.font(context);

    expect([labels.align, labels.position, fonts.map((font) => font.weight), fonts[1].size < fonts[0].size])
      .toEqual(['left', 'top', ['600', undefined], true]);
  });

  // The server sends the largest entry first, the rest belongs at the end
  it('keeps the tiles in the order of the server', () => {
    const treemap = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' }));

    expect(treemap.data.datasets[0].unsorted).toBe(true);
  });

  // Two versions "1.0" of different projects must not become one tile
  it('keeps tiles with the same name apart', () => {
    const tiles = treemapTiles(payload({ type: 'treemap', labels: ['1.0', '1.0'] }));

    expect(tiles.map((tile) => tile.value)).toEqual([3, 1]);
  });

  it('labels a tile with its name or the text of the server instead', () => {
    const named = treemapTiles(payload({ type: 'treemap' }));
    const sized = treemapTiles(payload({ type: 'treemap', tileLabels: ['8 MB', '1 MB'] }));

    expect([named[0].tile, sized[0].tile, sized[0].name]).toEqual(['Bug', '8 MB', 'Bug']);
  });

  it('merges the tiles below 0.01 % into the rest named by the server', () => {
    const tiles = treemapTiles(payload({ type: 'treemap', restLabel: 'Rest', labels: ['A', 'B', 'C'],
      datasets: [{ data: [100000, 5, 4], urls: ['/a', '/b', '/c'] }], total: 100009 }));

    expect(tiles.map((tile) => [tile.name, tile.value, Boolean(tile.rest)])).toEqual([['A', 100000, false], ['Rest', 9, true]]);
  });

  // A single small tile keeps its own name and link
  it('keeps a single small tile on its own', () => {
    const tiles = treemapTiles(payload({ type: 'treemap', restLabel: 'Rest', labels: ['A', 'B'],
      datasets: [{ data: [100000, 5], urls: ['/a', '/b'] }], total: 100005 }));

    expect(tiles.map((tile) => tile.name)).toEqual(['A', 'B']);
  });

  // A rest without a name would be a tile nobody can read
  it('merges no tiles without a name for the rest', () => {
    const tiles = treemapTiles(payload({ type: 'treemap', labels: ['A', 'B', 'C'],
      datasets: [{ data: [100000, 5, 4], urls: ['/a', '/b', '/c'] }], total: 100009 }));

    expect(tiles).toHaveLength(3);
  });

  it('puts the largest tile first', () => {
    const tiles = treemapTiles(payload({ type: 'treemap', labels: ['Small', 'Large'], datasets: [{ data: [1, 3] }] }));

    expect(tiles.map((tile) => tile.name)).toEqual(['Large', 'Small']);
  });

  it('opens the entry of a clicked tile, but nothing for the rest', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    const treemap = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' }));
    const click = (tile) => treemap.options.onClick(null, [], {
      getElementsAtEventForMode: () => [{ index: 0 }],
      data: { datasets: [{ data: [{ _data: tile }] }] },
    });
    click({ url: '/issues?tracker=1' });
    click({ rest: true, url: null });

    expect(open.mock.calls).toEqual([['/issues?tracker=1']]);
    open.mockRestore();
  });

  // While the tiles grow, a click must find the tile at its final place
  it('looks for a clicked tile at its final place', () => {
    const treemap = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' }));
    const find = vi.fn(() => []);
    treemap.options.onClick(null, [], { getElementsAtEventForMode: find, data: { datasets: [{ data: [] }] } });

    expect(find.mock.calls[0][3]).toBe(true);
  });

  it('names value, share and the tooltip line of a tile in its tooltip', () => {
    const data = payload({ type: 'treemap', datasets: [{ label: 'Issues', data: [3, 1], tooltips: ['Project: <b>A</b>', null] }] });
    const treemap = treemapConfig(document.createElement('canvas'), data);
    const [tile] = treemapTiles(data);
    const { callbacks } = treemap.options.plugins.tooltip;
    const item = { raw: { _data: tile, v: 3 } };

    expect([callbacks.title([item]), callbacks.label(item)]).toEqual(['Bug', ['Quantity: 3 (75%)', 'Project: <b>A</b>']]);
  });

  it('names only the share in the tooltip of the rest', () => {
    const treemap = treemapConfig(document.createElement('canvas'), payload({ type: 'treemap' }));
    const item = { raw: { _data: { name: 'Rest', rest: true, value: 1 }, v: 1 } };

    expect(treemap.options.plugins.tooltip.callbacks.label(item)).toEqual(['Quantity: 25%']);
  });

  it('writes the share with a decimal where it is small', () => {
    expect([percentText(1, 300), percentText(0, 0)]).toEqual(['0.3%', '0%']);
  });
});

describe('treemap labels', () => {
  // Every character as wide as half its font size
  const measure = (text, size) => text.length * size * 0.5;

  it('writes name and share as large as the tile allows', () => {
    expect(treemapLabelLayout(['Office', '4.1%'], 400, 300, measure)).toEqual({ size: 28, lines: ['Office', '4.1%'] });
  });

  it('makes the text smaller to fit a narrow tile', () => {
    expect(treemapLabelLayout(['Office', '4.1%'], 60, 300, measure).size).toBe(17);
  });

  it('wraps a long name at spaces', () => {
    expect(treemapLabelLayout(['Munich Folk Theatre', '4.1%'], 200, 300, measure).lines).toEqual(['Munich Folk', 'Theatre', '4.1%']);
  });

  // Subjects of issues rarely fit, as much of them as the tile holds tells more than nothing
  it('shortens a name that does not fit to the lines the tile holds', () => {
    expect(treemapLabelLayout(['Nameserver change for the web project of the city', '1.5%'], 100, 60, measure))
      .toEqual({ size: 11, lines: ['Nameserver', 'change for the…', '1.5%'] });
  });

  it('splits a word too long for a line where the tile has more lines', () => {
    expect(treemapLabelLayout(['Stornoformular funktioniert', '4.1%'], 70, 100, measure))
      .toEqual({ size: 13, lines: ['Stornofo-', 'rmular', 'funktion-', 'iert', '4.1%'] });
  });

  // "Kraft-Wärme" split after its own hyphen must not show two
  it('adds no second hyphen where a split word has one', () => {
    const lines = Array.from({ length: 40 }, (_v, index) => treemapLabelLayout(['Kraft-Waermekopplung', '1%'], 40 + index, 80, measure))
      .flatMap((layout) => layout?.lines || []);

    expect(lines.filter((line) => line.includes('--'))).toEqual([]);
  });

  it('shortens a word longer than the tile', () => {
    expect(treemapLabelLayout(['Notificationservice', '0.4%'], 60, 40, measure)).toEqual({ size: 11, lines: ['Notifica…', '0.4%'] });
  });

  it('writes a shortened name smaller where that shows more of it', () => {
    expect(treemapLabelLayout(['Daily Standup Meeting', '0.6%'], 52, 55, measure))
      .toEqual({ size: 11, lines: ['Daily', 'Standup…', '0.6%'] });
  });

  // A short last line must not throw away the lines above it
  it('ends a short last line in the ellipsis', () => {
    expect(treemapLabelLayout(['Kalender B: Planung', '1%'], 52, 50, measure)).toEqual({ size: 11, lines: ['Kalender', 'B:…', '1%'] });
  });

  it('shows only the share where no name fits', () => {
    expect(treemapLabelLayout(['Office', '4.1%'], 30, 30, measure)).toEqual({ size: 11, lines: ['4.1%'] });
  });

  // Text below the smallest size cannot be read, the name is in the tooltip
  it('leaves a tile empty where not even the share fits', () => {
    expect([treemapLabelLayout(['Office', '4.1%'], 15, 300, measure),
      treemapLabelLayout(['Office', '4.1%'], 300, 12, measure)]).toEqual([null, null]);
  });

  it('writes dark text on light tiles and light text on dark ones', () => {
    expect(['#ffdd71', '#b10318', 'rgb(255, 255, 255)', '#000'].map((color) => contrastingText(color, 'dark', 'light')))
      .toEqual(['dark', 'light', 'dark', 'light']);
  });
});

describe('quiet style', () => {
  it('writes axes and legends in the muted color', () => {
    const canvas = canvasWith({ '--a-color-muted': 'rgb(153, 153, 153)' });

    expect(chartConfig(canvas, payload({ type: 'bar_vertical' })).options.color).toBe('rgb(153, 153, 153)');
  });

  it('writes the labels of the axes in the muted color', () => {
    const canvas = canvasWith({ '--a-color-muted': 'rgb(153, 153, 153)' });

    expect(chartConfig(canvas, payload({ type: 'line' })).options.scales.x.ticks.color).toBe('rgb(153, 153, 153)');
  });

  it('writes in a small font', () => {
    expect(chartConfig(document.body, payload({ type: 'bar_vertical' })).options.font.size).toBe(11);
  });

  it('draws no lines along the entries', () => {
    expect(chartConfig(document.body, payload({ type: 'bar_horizontal' })).options.scales.y.grid.display).toBe(false);
  });

  it('lets the dates of a timeline slant to show more of them', () => {
    expect(chartConfig(document.body, payload({ type: 'line' })).options.scales.x.ticks.maxRotation).toBeUndefined();
  });

  it('writes the rows of a matrix in the muted color', () => {
    const canvas = canvasWith({ '--a-color-muted': 'rgb(153, 153, 153)' });
    const matrix = { columns: ['Mon'], rows: ['Anna'], cells: [] };

    expect(matrixConfig(canvas, payload({ type: 'matrix', matrix })).options.scales.y.ticks.color).toBe('rgb(153, 153, 153)');
  });

  it('writes the weekdays of a calendar in the muted color', () => {
    const canvas = canvasWith({ '--a-color-muted': 'rgb(153, 153, 153)' });

    expect(calendarConfig(calendarPayload(), canvas).options.scales.y.ticks.color).toBe('rgb(153, 153, 153)');
  });

  it('keeps the weekdays of a calendar', () => {
    const { ticks } = calendarConfig(calendarPayload(), document.body).options.scales.y;

    expect(ticks.callback(0)).toBe('Mo');
  });
});

describe('language of the page', () => {
  afterEach(() => {
    document.documentElement.lang = '';
  });

  it('formats the numbers of Chart.js in the language of the page', () => {
    document.documentElement.lang = 'de';

    expect(chartConfig(document.body, payload({ type: 'bar_vertical' })).options.locale).toBe('de');
  });

  it('leaves the language to the browser without one of the page', () => {
    expect(pageLocale()).toBeUndefined();
  });

  it('formats a value without a text of the server in the language of the page', () => {
    document.documentElement.lang = 'de';

    expect(formatNumber(25000.5)).toBe('25.000,5');
  });

  it('keeps a text as it is', () => {
    expect(formatNumber('8 h')).toBe('8 h');
  });
});

describe('sankey', () => {
  it('draws a sankey with the sankey plugin of Chart.js, without names at the nodes', () => {
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());

    expect([sankey.type, sankey.data.datasets[0].nodeLabels.display]).toEqual(['sankey', false]);
  });

  it('makes a parent as thick as its children', () => {
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());

    expect(sankey.data.datasets[0].data.map(({ from, to, flow }) => [from, to, flow]))
      .toEqual([['root', 'a', 2], ['root', 'b', 1], ['a', 'c', 1], ['a', 'd', 1]]);
  });

  // A family stands out at every level, also where one branch holds almost all
  it('gives the children of a parent one color, the next family the next color', () => {
    window.Chart = { colorschemes: { test: { dark: ['#aa0000', '#006600', '#0000aa'] } } };
    const { colorTo } = sankeyConfig(document.createElement('canvas'), { ...sankeyPayload(), colorSchema: 'test.dark' }).data.datasets[0];
    const colors = [['root', 'a'], ['root', 'b'], ['a', 'c'], ['a', 'd']].map(([from, to]) => colorTo({ raw: { from, to } }));
    delete window.Chart;

    expect(colors).toEqual(['#aa0000', '#aa0000', '#006600', '#006600']);
  });

  // Light colors of sequential schemes vanish on white, e.g. the yellow of YlGnBu
  it('leaves out colors of the scheme too light for thin flows', () => {
    window.Chart = { colorschemes: { test: { light: ['#ffffd9', '#edf8b1', '#41b6c4', '#081d58'] } } };
    const { colorTo } = sankeyConfig(document.createElement('canvas'), { ...sankeyPayload(), colorSchema: 'test.light' }).data.datasets[0];
    const colors = [['root', 'a'], ['a', 'c']].map(([from, to]) => colorTo({ raw: { from, to } }));
    delete window.Chart;

    expect(colors).toEqual(['#41b6c4', '#081d58']);
  });

  // The plugin delays each flow by 20 ms, a large tree took several seconds to appear
  it('lets even a large tree appear within a short time', () => {
    const many = { type: 'sankey', sankey: { nodes: [{ id: 'root', name: 'Projects' }], links: [] } };
    for (let index = 0; index < 500; index += 1) {
      many.sankey.nodes.push({ id: `p${index}`, name: `P${index}` });
      many.sankey.links.push({ source: 'root', target: `p${index}` });
    }
    const { delay } = sankeyConfig(document.createElement('canvas'), many).data.datasets[0].animations.progress;

    expect(delay({ type: 'data', dataIndex: 499, parsed: { x: 0 } })).toBeLessThanOrEqual(500);
  });

  it('puts each level of the hierarchy in a column of its own', () => {
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());

    expect(sankey.data.datasets[0].column).toEqual({ root: 0, a: 1, b: 1, c: 2, d: 2 });
  });

  // The plugin knows flows only
  it('finds a node at the ends of its flows', () => {
    const chart = sankeyChart(sankeyConfig(document.createElement('canvas'), sankeyPayload()));

    expect([sankeyNodeAt(chart, 105, 20), sankeyNodeAt(chart, 5, 20), sankeyNodeAt(chart, 50, 20)])
      .toEqual([{ key: 'a', index: 0 }, { key: 'root', index: 0 }, null]);
  });

  it('names the node or both ends of a flow in the tooltip', () => {
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());
    const { title } = sankey.options.plugins.tooltip.callbacks;
    const item = (node) => ({ chart: { $additionalsSankeyNode: node }, raw: { from: 'root', to: 'a' } });

    expect([title([item('a')]), title([item(null)])]).toEqual(['<b>A</b>', 'Projects → <b>A</b>']);
  });

  it('opens a clicked node, for a flow the node it leads to, nothing for the root', () => {
    const open = vi.spyOn(window, 'open').mockImplementation(() => null);
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());
    const [events] = sankey.plugins;
    const click = (x, y, flows = []) => events.afterEvent(sankeyChart(sankey, () => flows), { event: { type: 'click', x, y } });
    click(105, 20);
    click(150, 20, [{ datasetIndex: 0, index: 2 }]);
    click(5, 20);

    expect(open.mock.calls).toEqual([['/projects/a'], ['/projects/c']]);
    open.mockRestore();
  });

  it('shows the hand where a click opens a project', () => {
    const sankey = sankeyConfig(document.createElement('canvas'), sankeyPayload());
    const [events] = sankey.plugins;
    const cursor = (x, y) => {
      const chart = sankeyChart(sankey);
      events.afterEvent(chart, { event: { type: 'mousemove', x, y } });
      return chart.canvas.style.cursor;
    };

    expect([cursor(105, 20), cursor(5, 20)]).toEqual(['pointer', '']);
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

    expect(datasets[1].order).toBeLessThan(datasets[0].order);
  });

  // Chart.js draws a lower order above a higher one
  it('draws a later line on top above an earlier one', () => {
    const { datasets } = chartConfig(null, burndownPayload({ datasets: [{ label: 'Total', data: [3, 2, null], onTop: true },
      { label: 'Compare', data: [3, 2, null], onTop: true }] })).data;

    expect(datasets[1].order).toBeLessThan(datasets[0].order);
  });

  it('keeps the legend in the order of the payload', () => {
    const { sort } = chartConfig(null, burndownPayload()).options.plugins.legend.labels;

    expect([{ datasetIndex: 1 }, { datasetIndex: 0 }].sort(sort).map((item) => item.datasetIndex)).toEqual([0, 1]);
  });

  it('keeps the tooltip in the order of the payload', () => {
    const { itemSort } = chartConfig(null, burndownPayload()).options.plugins.tooltip;

    expect([{ datasetIndex: 1 }, { datasetIndex: 0 }].sort(itemSort).map((item) => item.datasetIndex)).toEqual([0, 1]);
  });

  // E.g. statuses stacked with the closed ones at the bottom, listed as sorted
  it('orders legend and tooltip by the legend order of the datasets', () => {
    const { plugins } = chartConfig(null, burndownPayload({ datasets: [{ label: 'Closed', data: [1], legendOrder: 2 },
      { label: 'New', data: [1], legendOrder: 1 }, { label: 'Compare', data: [1] }] })).options;
    const items = [{ datasetIndex: 0 }, { datasetIndex: 1 }, { datasetIndex: 2 }];

    expect([...items].sort(plugins.legend.labels.sort).map((item) => item.datasetIndex)).toEqual([1, 0, 2]);
    expect([...items].sort(plugins.tooltip.itemSort).map((item) => item.datasetIndex)).toEqual([1, 0, 2]);
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

  it('draws a line of values per period as steps', () => {
    const datasets = [{ label: 'Spent', data: [3, 0] }, { label: 'Target', data: [8, 0], type: 'line', stepped: true }];
    const line = chartConfig(document.body, payload({ type: 'bar_vertical', datasets })).data.datasets[1];

    expect(line.stepped).toBe('middle');
  });

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

  // A line is no part of the bar, a share of it would make no sense
  it('keeps the values of a line', () => {
    const data = sharePayload();
    data.datasets.push({ label: 'Last year', type: 'line', data: [5, 50] });

    expect(shareDatasets(data)[2].data).toEqual([5, 50]);
  });

  it('names the ticks of the value axis in the language of the page', () => {
    document.documentElement.lang = 'de';
    const { callback } = chartConfig(null, sharePayload()).options.scales.y.ticks;
    const text = callback(12.5);
    document.documentElement.lang = '';

    expect(text).toBe('12,5 %');
  });

  it('shows the share inside a part', () => {
    const { formatter } = chartConfig(null, sharePayload()).options.plugins.datalabels;

    expect(formatter(25, { datasetIndex: 0, dataIndex: 0 })).toBe('25 %');
  });

  // The share is shown, not the value, so the room for the share counts
  it('shows a share that fits in a part where its value would not', () => {
    const data = sharePayload();
    data.valueTexts = [['1.234.567,89 EUR', '1 EUR'], ['3 EUR', '7 EUR']];
    const { display } = chartConfig(null, data).options.plugins.datalabels;
    const context = {
      ...partContext({ y: 0, base: 60, width: 50 }),
      dataset: data.datasets[0],
    };

    expect(display(context)).toBe(true);
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

  // A period without value, e.g. a future day of a burndown, is no decimal
  it('counts in whole steps across a gap', () => {
    expect(valueTicks(payload({ datasets: [{ label: 'Issues', data: [3, null] }] }))).toEqual({ precision: 0 });
  });

  it('applies to the value axis of a timeline', () => {
    const { options } = chartConfig(null, payload({ type: 'area', datasets: [{ label: 'Pages', data: [0, 4] }] }));

    expect(options.scales.y.ticks.precision).toBe(0);
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
    ctx.drawSankey = prototype.drawSankey.bind(ctx);
    ctx.drawTreemap = prototype.drawTreemap.bind(ctx);
    ctx.drawCalendar = prototype.drawCalendar.bind(ctx);
    ctx.drawWithLines = prototype.drawWithLines.bind(ctx);
    ctx.drawMatrix = prototype.drawMatrix.bind(ctx);
    ctx.loaded = prototype.loaded.bind(ctx);
    return ctx;
  }

  beforeEach(() => {
    globalThis.AdditionalsHelpers.loadLibrary = vi.fn(() => Promise.resolve());
    globalThis.Chart = vi.fn(function chart() {
      this.destroy = vi.fn();
    });
    // The legend of a calendar colors its levels
    globalThis.Chart.helpers = { color: () => ({ alpha: () => ({ rgbString: () => 'rgb(0, 0, 0)' }) }) };
    globalThis.Chart.Interaction = { modes: {} };
    globalThis.Chart.Tooltip = { positioners: {} };
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

  it('reports a failed load of a plugin in the console', async () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    AdditionalsHelpers.loadLibrary.mockReturnValue(Promise.reject(new Error('Could not load')));
    controller(sankeyPayload()).connect();
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

  it('loads the treemap plugin for a treemap', () => {
    controller(payload({ type: 'treemap' })).connect();

    expect(AdditionalsHelpers.loadLibrary).toHaveBeenCalledWith('chartjs_treemap');
  });

  it('draws the treemap on its canvas once the plugin is there', async () => {
    const ctrl = controller(payload({ type: 'treemap' }));
    await ctrl.drawTreemap(payload({ type: 'treemap' }));

    expect([Chart.mock.calls[0][0], Chart.mock.calls[0][1].type]).toEqual([ctrl.canvasTarget, 'treemap']);
  });

  it('loads the sankey plugin for a sankey', () => {
    controller(sankeyPayload()).connect();

    expect(AdditionalsHelpers.loadLibrary).toHaveBeenCalledWith('chartjs_sankey');
  });

  it('draws the sankey on its canvas once the plugin is there', async () => {
    const ctrl = controller(sankeyPayload());
    await ctrl.drawSankey(sankeyPayload());

    expect([Chart.mock.calls[0][0], Chart.mock.calls[0][1].type]).toEqual([ctrl.canvasTarget, 'sankey']);
  });

  // Tooltip and pointer need to know nodes, which the plugin does not
  it('registers how a sankey finds its nodes', async () => {
    await controller(sankeyPayload()).drawSankey(sankeyPayload());

    expect(Chart.Interaction.modes.additionalsSankey).toBeTypeOf('function');
  });

  // The block may be reloaded while the plugin is loading
  it('draws no treemap into a removed block', async () => {
    const ctrl = controller(payload({ type: 'treemap' }));
    ctrl.element.remove();
    await ctrl.drawTreemap(payload({ type: 'treemap' }));

    expect(Chart).not.toHaveBeenCalled();
  });

  it('draws no calendar into a removed block', async () => {
    const ctrl = controller(calendarPayload());
    ctrl.element.remove();
    await ctrl.drawCalendar(calendarPayload());

    expect(Chart).not.toHaveBeenCalled();
  });

  it('draws no matrix into a removed block', async () => {
    const data = payload({ type: 'matrix', matrix: { columns: [], rows: [], cells: [] } });
    const ctrl = controller(data);
    ctrl.element.remove();
    await ctrl.drawMatrix(data);

    expect(Chart).not.toHaveBeenCalled();
  });

  it('draws no lines across the chart into a removed block', async () => {
    const data = payload({ type: 'line', lines: [{ axis: 'x', value: 1, label: 'Today' }] });
    const ctrl = controller(data);
    ctrl.element.remove();
    await ctrl.drawWithLines(data);

    expect(Chart).not.toHaveBeenCalled();
  });

  // Stimulus connects a moved block again, the first library load ends later
  it('draws once when the block connects again while the library is loading', async () => {
    const loads = [];
    AdditionalsHelpers.loadLibrary.mockImplementation(() => new Promise((resolve) => { loads.push(resolve); }));
    const data = payload({ type: 'line', lines: [{ axis: 'x', value: 1, label: 'Today' }] });
    const ctrl = controller(data);
    ctrl.connect();
    ctrl.disconnect();
    ctrl.connect();
    loads.forEach((resolve) => resolve());
    await new Promise((resolve) => { setTimeout(resolve, 0); });

    expect(Chart).toHaveBeenCalledTimes(1);
  });

  it('removes the legend of a calendar when the block goes away', async () => {
    const ctrl = controller(calendarPayload());
    await ctrl.drawCalendar(calendarPayload());
    ctrl.disconnect();

    expect(document.querySelector('.additionals-calendar-legend')).toBeNull();
  });
});
