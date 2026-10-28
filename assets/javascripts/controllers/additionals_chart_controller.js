/* global Chart, ChartDataLabels */
import { Controller } from '@hotwired/stimulus';

// Draws a chart block from the payload the server renders into a data
// attribute (AdditionalsQueryChart#payload), so no value is interpolated into
// JavaScript. Chart.js draws doughnut, pie, bars, lines, areas, matrix,
// calendar, treemap and sankey. A click on a slice opens the list filtered by
// its value.
//
// Chart.js and its plugins come from the libraries of the block. The plugins
// only some charts need (matrix and calendar, treemap, sankey) are loaded on
// demand through the library registry.
// Blocks loaded asynchronously connect like any other element, and a reloaded
// or removed block releases its chart.

const BAR_TYPES = ['bar_horizontal', 'bar_vertical'];
const LINE_TYPES = ['line', 'area'];
const PIE_TYPES = ['doughnut', 'pie'];
const LINE_POINT_RADIUS = 3;
// Lines without points show one on hover, close enough to find it
const LINE_POINT_HIT_RADIUS = 8;
// Opacity of a filled line at the top and the bottom of its gradient
const AREA_GRADIENT_ALPHA = [0.35, 0.02];
// Lines of a role of their own, e.g. the ideal line of a burndown
const LINE_DASHES = { dashed: [6, 4], dotted: [2, 3] };
// Marks above a bar, e.g. the best and the worst month: a gold star, the worst
// one stays unobtrusive. Glyphs instead of emoji look the same on every system.
const MARKERS = { best: ['★', '--oc-yellow-8'], worst: ['↯', '--a-color-muted'] };
const MARKER_FONT_SIZE = 14;
const MARKER_SPACE = MARKER_FONT_SIZE + 8;
// Lines of a timeline with more periods would hide behind their points
const MAX_PERIODS_WITH_POINTS = 60;
// A pie legend with more entries pushes the pie into a corner and is cut off;
// tooltip and table of values name the slices then
const MAX_LEGEND_ENTRIES = 10;
// Value labels at the end of a bar, size as Chart.js draws them by default
const VALUE_LABEL_FONT_SIZE = 12;
const VALUE_LABEL_PADDING = 2;
// Average width of a digit relative to the font size, digits are the bulk of a value
const DIGIT_WIDTH_FACTOR = 0.6;
// Degrees a value label is turned when it is wider than its vertical bar
const VALUE_LABEL_SLANT = 45;
// Opacity of the color per level of a calendar, days without values first
const CALENDAR_ALPHAS = [0.08, 0.3, 0.5, 0.72, 0.95];
const CALENDAR_FALLBACK_COLOR = '#1f77b4';
// Axes, legends and titles in the font of the page at this size
const CHART_FONT_SIZE = 11;
// Bars of the color scheme are filled with its colors at this alpha
const BAR_FILL_ALPHA = 0.8;
const CALENDAR_GAP = 2;
// Space between two month names
const CALENDAR_MONTH_GAP = 4;
// Gap between the cells of a matrix of rows and columns
const MATRIX_GAP = 4;
// Tiles of a treemap below this share of the total merge into the rest
const TREEMAP_REST_SHARE = 0.0001;
// Text on a tile is as large as it fits, smaller than the minimum it is left out
const TREEMAP_FONT_MAX = 28;
const TREEMAP_FONT_MIN = 11;
// A name that does not fit is shortened in this size, with at least a few characters
const TREEMAP_FONT_SHORT = 13;
const TREEMAP_SHORT_MIN_CHARS = 3;
const TREEMAP_LINE_HEIGHT = 1.2;
const TREEMAP_PADDING = 4;
const TREEMAP_SPACING = 2;
const TREEMAP_RADIUS = 4;
// The name is bold, the share below it smaller and a bit lighter
const TREEMAP_NAME_WEIGHT = '600';
const TREEMAP_SHARE_SCALE = 0.75;
const TREEMAP_SHARE_ALPHA = 0.75;
// A tile under the pointer lightens up
const TREEMAP_HOVER_ALPHA = 0.82;
// A tile is drawn smaller than its area by the spacing on both sides and the
// rounding to whole pixels, the text must fit the drawn tile
const TREEMAP_INSET = (2 * TREEMAP_SPACING) + 1;
// Relative luminance above which dark text has the better contrast (WCAG)
const LIGHT_LUMINANCE = 0.179;
// Width of the nodes of a sankey and how far a pointer may miss one; a node
// is never harder to hit than one of this height
const SANKEY_NODE_WIDTH = 10;
// Room between the nodes of a column
const SANKEY_NODE_PADDING = 24;
const SANKEY_FLOW_ALPHA = 0.35;
// Lightest color of the scheme a flow is drawn in, as relative luminance
const SANKEY_MAX_LUMINANCE = 0.6;
// Delay of the flows while the sankey appears: per column, per flow and for
// all flows of a column at most, in ms
const SANKEY_COLUMN_DELAY = 150;
const SANKEY_FLOW_DELAY = 20;
const SANKEY_FLOWS_DELAY = 500;
const SANKEY_HIT_TOLERANCE = 2;
const SANKEY_MIN_HIT_HEIGHT = 4;
// Names of the interaction mode and the tooltip position of a sankey
const SANKEY_MODE = 'additionalsSankey';
const SANKEY_POSITIONER = 'additionalsPointer';

// Reads a CSS custom property from an element. Canvas cannot resolve var().
function cssVar(el, name) {
  return getComputedStyle(el).getPropertyValue(name).trim();
}

function openUrl(url) {
  if (url) {
    window.open(url);
  }
}

// The language of the page, which Redmine sets to the one of the user.
// Without it Chart.js formats numbers in the language of the browser.
export function pageLocale() {
  return document.documentElement.lang || undefined;
}

export function formatNumber(value) {
  return typeof value === 'number' ? new Intl.NumberFormat(pageLocale()).format(value) : String(value);
}

// Values as the table of values shows them, e.g. hours in the format of the
// user. Payloads without texts show the number in the language of the page.
function valueText(payload, datasetIndex, index) {
  const texts = payload.valueTexts && payload.valueTexts[datasetIndex];
  return texts ? texts[index] : formatNumber(payload.datasets[datasetIndex].data[index]);
}

function share(value, total) {
  return total > 0 ? Math.round((value * 100) / total) : 0;
}

// Each series links to the list of its own query
function entryUrl(payload, datasetIndex, index) {
  const { urls } = payload.datasets[datasetIndex];
  return urls ? urls[index] : null;
}

function clickHandler(payload) {
  return (_event, elements) => {
    if (elements.length > 0) {
      openUrl(entryUrl(payload, elements[0].datasetIndex, elements[0].index));
    }
  };
}

// Where the tooltip covers a whole column, a click still opens the list of
// the bar under the pointer, not of the first part of the column
function pointerClickHandler(payload) {
  return (event, _elements, chart) => {
    const [element] = chart.getElementsAtEventForMode(event, 'nearest', { intersect: true }, false);
    if (element) {
      openUrl(entryUrl(payload, element.datasetIndex, element.index));
    }
  };
}

// Line below the value of a point or bar in its tooltip, e.g. how many
// entries a median stands for, formatted by the server
export function tooltipLine(context) {
  return context.dataset.tooltips?.[context.dataIndex] || '';
}

// Ticks of a value axis: counts in whole steps, not 0.5 between 0 and 1.
// A gap without value (null) is no decimal.
export function valueTicks(payload) {
  const counts = payload.datasets.every((dataset) => dataset.data.every((value) => value === null || Number.isInteger(value)));
  return counts ? { precision: 0 } : {};
}

function datalabelsPlugins() {
  return typeof ChartDataLabels === 'undefined' ? [] : [ChartDataLabels];
}

function pieConfig(canvas, payload) {
  const doughnut = payload.type === 'doughnut';
  const fontFamily = getComputedStyle(document.body).fontFamily || 'sans-serif';
  const plugins = {
    legend: {
      display: payload.labels.length <= MAX_LEGEND_ENTRIES,
    },
    colorschemes: {
      scheme: payload.colorSchema,
      fillAlpha: 0.8,
    },
    tooltip: {
      callbacks: {
        label(context) {
          const percentage = share(context.raw, payload.total);
          return `${context.label}: ${valueText(payload, 0, context.dataIndex)} (${percentage}%)`;
        },
      },
    },
  };

  if (doughnut) {
    plugins.annotation = {
      annotations: {
        total: {
          type: 'doughnutLabel',
          content: [payload.totalText || formatNumber(payload.total), payload.totalLabel],
          font: [
            { family: fontFamily, size: 22, weight: '600' },
            { family: fontFamily, size: 11 },
          ],
          color: [cssVar(canvas, '--a-color-default'), cssVar(canvas, '--a-color-muted')],
        },
      },
    };
  }

  return {
    type: doughnut ? 'doughnut' : 'pie',
    data: {
      labels: payload.labels,
      datasets: [payload.datasets[0]],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      onClick: clickHandler(payload),
      plugins,
    },
  };
}

// A line in a bar chart, e.g. the year before as comparison
function isLine(dataset) {
  return dataset.type === 'line';
}

// A series of another unit, e.g. counts next to days, on an axis of its own
function isSecondary(dataset) {
  return dataset.axis === 'secondary';
}

function estimatedTextWidth(text) {
  return Math.ceil(text.length * VALUE_LABEL_FONT_SIZE * DIGIT_WIDTH_FACTOR);
}

function longestValueWidth(payload) {
  if (payload.valueLabels === false) {
    return 0;
  }
  return payload.datasets.reduce((max, dataset, datasetIndex) => Math.max(
    max,
    ...dataset.data.map((_value, index) => estimatedTextWidth(valueText(payload, datasetIndex, index))),
  ), 0);
}

// The value labels sit behind the end of a bar. Without room for them the
// longest bar pushes its label out of the canvas. Above vertical bars a label
// may be slanted, see valueLabelRotation.
function valueLabelSpace(payload, horizontal) {
  const labelPadding = (2 * VALUE_LABEL_PADDING) + 4;
  const longest = longestValueWidth(payload);
  if (horizontal) {
    return { right: longest + labelPadding };
  }

  const slanted = Math.SQRT1_2 * (longest + VALUE_LABEL_FONT_SIZE);
  return { top: Math.ceil(Math.max(slanted, VALUE_LABEL_FONT_SIZE)) + labelPadding };
}

// A value wider than its vertical bar would run into the label of the next
// bar, e.g. next to a comparison. Slanted labels lie parallel and keep apart.
function valueLabelRotation(payload, context) {
  const bar = context.chart.getDatasetMeta(context.datasetIndex).data[context.dataIndex];
  const text = valueText(payload, context.datasetIndex, context.dataIndex);
  return bar && estimatedTextWidth(text) > bar.width ? -VALUE_LABEL_SLANT : 0;
}

// Sum of all parts of an entry, the length of its stacked bar
function rowTotal(payload, index) {
  return payload.datasets.reduce((sum, dataset) => (isLine(dataset) ? sum : sum + (dataset.data[index] || 0)), 0);
}

// Value labels are shown for bars only, and not at all on request
function showValueLabel(payload, context) {
  return payload.valueLabels !== false && !isLine(context.dataset) && context.dataset.data[context.dataIndex] !== 0;
}

// A part of a stacked bar shows its value inside, if the value fits in
function valueFitsInPart(payload, context, horizontal) {
  const bar = context.chart.getDatasetMeta(context.datasetIndex).data[context.dataIndex];
  if (!bar) {
    return false;
  }

  const textWidth = estimatedTextWidth(partLabel(payload, context.datasetIndex, context.dataIndex));
  // The labels are placed before the bars grow, so the size they grow to counts
  const {
    x, y, base, width, height,
  } = bar.getProps(['x', 'y', 'base', 'width', 'height'], true);
  const length = Math.abs(horizontal ? x - base : y - base);
  const thickness = horizontal ? height : width;
  const needed = 2 * VALUE_LABEL_PADDING;
  return horizontal
    ? length >= textWidth + needed && thickness >= VALUE_LABEL_FONT_SIZE + needed
    : length >= VALUE_LABEL_FONT_SIZE + needed && thickness >= textWidth + needed;
}

// Parts of an entry stack up to one bar, their values sit inside the parts
function stackedOptions(payload, horizontal) {
  return {
    scales: {
      x: { stacked: true },
      y: { stacked: true },
    },
    tooltip: {
      callbacks: {
        afterLabel: tooltipLine,
        label: (context) => {
          const text = `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)}`;
          // A comparison line is no part of the stack
          if (isLine(context.dataset)) {
            return text;
          }
          return `${text} (${formatNumber(partShare(payload, context.datasetIndex, context.dataIndex))}%)`;
        },
      },
    },
    datalabels: {
      anchor: 'center',
      align: 'center',
      padding: VALUE_LABEL_PADDING,
      display: (context) => showValueLabel(payload, context) && valueFitsInPart(payload, context, horizontal),
      formatter: (_value, context) => partLabel(payload, context.datasetIndex, context.dataIndex),
    },
  };
}

// Text inside a part of a stacked bar: its share as shares, its value otherwise
function partLabel(payload, datasetIndex, index) {
  return payload.percent
    ? `${formatNumber(partShare(payload, datasetIndex, index))} %`
    : valueText(payload, datasetIndex, index);
}

// Share of a part in its bar, from the values of the payload
function partShare(payload, datasetIndex, index) {
  return share(payload.datasets[datasetIndex].data[index], rowTotal(payload, index));
}

// Parts as shares of their bar, each bar up to 100 %, e.g. to compare the
// estimated part of few open with many closed issues. A line is no part of
// a bar and keeps its values.
export function shareDatasets(payload) {
  return payload.datasets.map((dataset) => (isLine(dataset) ? dataset : {
    ...dataset,
    data: dataset.data.map((value, index) => {
      const total = rowTotal(payload, index);
      return total > 0 ? (value * 100) / total : 0;
    }),
  }));
}

// A line in a bar chart lies above the bars in a stack of its own
function barDataset(dataset) {
  if (!isLine(dataset)) {
    return dataset;
  }
  return {
    ...dataset,
    stack: 'line',
    order: -1,
    fill: false,
    borderWidth: 2,
    borderDash: LINE_DASHES[dataset.style] || [],
    // A value per period, e.g. the working hours of a day: flat across the
    // period, the steps lie between two periods
    stepped: dataset.stepped ? 'middle' : false,
    pointRadius: LINE_POINT_RADIUS,
    pointHoverRadius: LINE_POINT_RADIUS + 1,
  };
}

// The bars a marker sits on: its own, in stacked bars all of its stack
function markedBars(chart, datasetIndex) {
  const { stack } = chart.data.datasets[datasetIndex];
  const stacked = chart.options.scales?.y?.stacked;
  return chart.data.datasets
    .map((dataset, other) => (stacked ? dataset.stack === stack && !isLine(dataset) : other === datasetIndex))
    .flatMap((included, other) => (included && chart.isDatasetVisible(other) ? [other] : []));
}

// Top of the bar of a marked entry, of its whole stack in stacked bars
export function markerTop(chart, datasetIndex, index) {
  const tops = markedBars(chart, datasetIndex)
    .map((other) => chart.getDatasetMeta(other).data[index])
    .filter(Boolean)
    .map((bar) => Math.min(bar.y, bar.base));
  return tops.length > 0 ? Math.min(...tops) : null;
}

// Draws the markers of datasets[].markers above their vertical bars
export function markerPlugin(canvas) {
  return {
    id: 'additionalsMarkers',
    afterDatasetsDraw(chart) {
      const { ctx } = chart;
      ctx.save();
      ctx.font = `bold ${MARKER_FONT_SIZE}px ${getComputedStyle(document.body).fontFamily || 'sans-serif'}`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'bottom';
      chart.data.datasets.forEach((dataset, datasetIndex) => {
        if (!dataset.markers || !chart.isDatasetVisible(datasetIndex)) {
          return;
        }
        dataset.markers.forEach((marker, index) => {
          const top = MARKERS[marker] ? markerTop(chart, datasetIndex, index) : null;
          if (top === null) {
            return;
          }
          const [glyph, color] = MARKERS[marker];
          ctx.fillStyle = cssVar(canvas, color);
          ctx.fillText(glyph, chart.getDatasetMeta(datasetIndex).data[index].x, top - 4);
        });
      });
      ctx.restore();
    },
  };
}

function hasMarkers(payload) {
  return payload.datasets.some((dataset) => dataset.markers?.some((marker) => MARKERS[marker]));
}

function barConfig(canvas, payload) {
  const horizontal = payload.type === 'bar_horizontal';
  const valueAxis = horizontal ? 'x' : 'y';
  const stacked = payload.stacked ? stackedOptions(payload, horizontal) : null;
  const datasets = payload.percent ? shareDatasets(payload) : payload.datasets;

  const config = {
    type: 'bar',
    data: {
      labels: payload.labels,
      datasets: datasets.map(barDataset),
    },
    options: {
      indexAxis: horizontal ? 'y' : 'x',
      responsive: true,
      maintainAspectRatio: false,
      onClick: clickHandler(payload),
      layout: {
        padding: valueLabelSpace(payload, horizontal),
      },
      scales: {
        [valueAxis]: {
          beginAtZero: true,
          ticks: valueTicks(payload),
          title: {
            display: true,
            text: payload.totalLabel,
          },
        },
      },
      plugins: {
        legend: {
          // Colors per bar leave the legend with the color of the first one
          display: payload.legend !== false && payload.datasets.length > 1,
          // The room for the values above vertical bars lies above the
          // legend, the values would run into it
          position: horizontal ? 'top' : 'bottom',
          // A comparison line drawn on top keeps its place of the payload
          labels: { sort: byLegendOrder(payload) },
        },
        colorschemes: {
          scheme: payload.colorSchema,
          fillAlpha: BAR_FILL_ALPHA,
        },
        tooltip: {
          callbacks: {
            label: (context) => `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)}`,
            afterLabel: tooltipLine,
          },
        },
        datalabels: {
          anchor: 'end',
          align: 'end',
          padding: VALUE_LABEL_PADDING,
          rotation: (context) => (horizontal ? 0 : valueLabelRotation(payload, context)),
          display: (context) => showValueLabel(payload, context),
          formatter: (_value, context) => valueText(payload, context.datasetIndex, context.dataIndex),
        },
      },
    },
    plugins: datalabelsPlugins(),
  };

  if (stacked) {
    const { options } = config;
    // Values sit inside the parts, no room needed behind the bars
    options.layout.padding = 0;
    options.scales = {
      x: { ...options.scales.x, ...stacked.scales.x },
      y: { ...options.scales.y, ...stacked.scales.y },
    };
    options.plugins.tooltip = stacked.tooltip;
    options.plugins.datalabels = stacked.datalabels;
  }
  // The tooltip keeps the order of the payload, a comparison line on top included
  config.options.plugins.tooltip.itemSort = byLegendOrder(payload);
  // Room above vertical bars for their markers. A marker may sit above an
  // empty period, so the tooltip covers the whole column and leaves out the
  // parts without value, but the one carrying the marker and its meaning.
  if (!horizontal && hasMarkers(payload)) {
    const { options } = config;
    const { padding } = options.layout;
    options.layout.padding = { ...(typeof padding === 'object' ? padding : {}), top: Math.max(padding?.top || 0, MARKER_SPACE) };
    options.interaction = { mode: 'index', intersect: false };
    options.onClick = pointerClickHandler(payload);
    options.plugins.tooltip.filter = (item) => isLine(item.dataset) || item.raw !== 0 || Boolean(item.dataset.markers?.[item.dataIndex]);
    config.plugins = [...config.plugins, markerPlugin(canvas)];
  }
  if (!horizontal && payload.datasets.some(isSecondary)) {
    secondaryAxis(config, payload);
  }
  if (payload.percent) {
    const axis = config.options.scales[valueAxis];
    axis.max = 100;
    axis.ticks = { callback: (value) => `${formatNumber(value)} %` };
  }

  return config;
}

// The series of another unit on an axis on the right, titled by
// secondaryLabel. Its lines across the chart would cross the ones of the
// left axis, each axis counts its ticks by its own values.
export function secondaryAxis(config, payload) {
  const { scales } = config.options;
  config.data.datasets = config.data.datasets.map((dataset) => (isSecondary(dataset) ? { ...dataset, yAxisID: 'y1' } : dataset));
  scales.y.ticks = valueTicks({ datasets: payload.datasets.filter((dataset) => !isSecondary(dataset)) });
  scales.y1 = {
    position: 'right',
    beginAtZero: true,
    ticks: valueTicks({ datasets: payload.datasets.filter(isSecondary) }),
    title: { display: true, text: payload.secondaryLabel },
    grid: { drawOnChartArea: false },
  };
}

// The series of a click in a period: the stacked area it lies in, the
// line next to it otherwise. The canvas counts y from the top down.
function clickedPoint(payload, event, chart) {
  if (!payload.stacked) {
    return chart.getElementsAtEventForMode(event, 'nearest', { intersect: false }, false)[0];
  }

  const points = chart.getElementsAtEventForMode(event, 'index', { intersect: false }, false)
    .sort((a, b) => a.datasetIndex - b.datasetIndex);
  return points.find((point) => point.element.y <= event.y);
}

function timelineClickHandler(payload) {
  return (event, _elements, chart) => {
    const point = clickedPoint(payload, event, chart);
    if (point) {
      openUrl(entryUrl(payload, point.datasetIndex, point.index));
    }
  };
}

// Stacked areas fill up to the area below them, all others down to the axis
function lineFill(payload, index) {
  if (payload.type !== 'area') {
    return false;
  }
  return payload.stacked && index > 0 ? '-1' : 'origin';
}

// A color with an opacity, for #rgb, #rrggbb and rgb() as CSS custom
// properties and color schemes hold them; other notations are returned unchanged
export function colorWithAlpha(color, alpha) {
  const parts = rgbParts(color);
  return parts ? `rgba(${parts.join(', ')}, ${alpha})` : color;
}

// Red, green and blue of #rgb, #rrggbb and rgb(), null for other notations
function rgbParts(color) {
  const rgb = /^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/.exec(color || '');
  if (rgb) {
    return rgb.slice(1).map(Number);
  }
  const hex = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(color || '');
  if (!hex) {
    return null;
  }
  const digits = hex[1].length === 3 ? hex[1].replace(/./g, '$&$&') : hex[1];
  return digits.match(/../g).map((part) => parseInt(part, 16));
}

// A filled line fades out towards the axis. The chart area is only known
// after the first layout, so it is a scriptable option; the color is the one
// of the line, set by the color scheme or the dataset.
export function areaGradient(context) {
  const { ctx, chartArea } = context.chart;
  const color = context.dataset.borderColor;
  if (!chartArea || typeof color !== 'string') {
    return 'rgba(0, 0, 0, 0)';
  }
  const gradient = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
  gradient.addColorStop(0, colorWithAlpha(color, AREA_GRADIENT_ALPHA[0]));
  gradient.addColorStop(1, colorWithAlpha(color, AREA_GRADIENT_ALPHA[1]));
  return gradient;
}

// The legend cannot show a gradient, a faded line shows its top color there
export function legendLabels(chart) {
  return Chart.defaults.plugins.legend.labels.generateLabels(chart).map((item) => {
    if (chart.data.datasets[item.datasetIndex].backgroundColor !== areaGradient) {
      return item;
    }
    return { ...item, fillStyle: colorWithAlpha(item.strokeStyle, AREA_GRADIENT_ALPHA[0]) };
  });
}

// Legend and tooltip list the datasets in the order of the payload, or by
// their legendOrder, e.g. statuses stacked with the closed ones at the bottom
// but listed as sorted; datasets without one follow in the order of the payload
function byLegendOrder(payload) {
  const key = (index) => {
    const order = payload.datasets[index]?.legendOrder;
    return order === undefined || order === null ? [1, index] : [0, order];
  };
  return (a, b) => {
    const [groupA, orderA] = key(a.datasetIndex);
    const [groupB, orderB] = key(b.datasetIndex);
    return groupA - groupB || orderA - orderB || a.datasetIndex - b.datasetIndex;
  };
}

// A timeline: one line or area per series, the tooltip names all series of a period
function lineConfig(payload) {
  const points = payload.points !== false && payload.labels.length <= MAX_PERIODS_WITH_POINTS;
  const datasets = payload.datasets.map((dataset, index) => ({
    ...dataset,
    fill: dataset.fill ?? lineFill(payload, index),
    borderDash: LINE_DASHES[dataset.style] || [],
    pointRadius: points ? LINE_POINT_RADIUS : 0,
    pointHoverRadius: LINE_POINT_RADIUS + 1,
    pointHitRadius: LINE_POINT_HIT_RADIUS,
    // A lower order is drawn above, a later line on top above an earlier one
    order: dataset.onTop ? -1 - index : 0,
    // A single filled line fades out, stacked areas keep their flat color
    ...(dataset.fill === true && !payload.stacked ? { backgroundColor: areaGradient } : {}),
  }));

  return {
    type: 'line',
    data: {
      labels: payload.labels,
      datasets,
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      onClick: timelineClickHandler(payload),
      interaction: {
        mode: 'index',
        intersect: false,
      },
      scales: {
        y: {
          beginAtZero: true,
          stacked: payload.stacked,
          ticks: valueTicks(payload),
          title: {
            display: true,
            text: payload.totalLabel,
          },
        },
      },
      plugins: {
        // Legend and tooltip keep the order of the payload, a line drawn on top included
        legend: {
          display: payload.legend !== false && payload.datasets.length > 1,
          position: 'bottom',
          labels: { sort: byLegendOrder(payload), generateLabels: legendLabels },
        },
        colorschemes: {
          scheme: payload.colorSchema,
          fillAlpha: 0.5,
        },
        tooltip: {
          itemSort: byLegendOrder(payload),
          callbacks: {
            label: (context) => `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)}`,
            afterLabel: tooltipLine,
          },
        },
      },
    },
  };
}

// Fixed colors of a dataset, one CSS custom property per point, e.g. red for
// overdue. They take the place of the color scheme for that dataset, a point
// without one keeps the color the scheme gives it (fallback by point index).
export function withColors(canvas, dataset, fallback = () => null) {
  if (dataset.color) {
    const color = cssVar(canvas, dataset.color);
    return {
      ...dataset,
      borderColor: color,
      backgroundColor: dataset.backgroundColor || color,
      pointBackgroundColor: color,
      pointBorderColor: color,
    };
  }
  if (!dataset.colors) {
    return dataset;
  }
  return {
    ...dataset,
    backgroundColor: dataset.colors.map((name, index) => (name ? cssVar(canvas, name) : fallback(index))),
  };
}

// Lines across the chart with a text, e.g. today on a burndown. On a
// category axis a value between two entries lies between them.
export function lineAnnotations(canvas, payload) {
  return Object.fromEntries((payload.lines || []).map((line, index) => {
    const color = cssVar(canvas, '--a-color-muted');
    const position = line.axis === 'x' ? { xMin: line.value, xMax: line.value } : { yMin: line.value, yMax: line.value };
    return [`line${index}`, {
      type: 'line',
      ...position,
      borderColor: color,
      borderDash: LINE_DASHES.dashed,
      borderWidth: 1,
      // A line across the values carries its text on the right, where the
      // latest periods are, e.g. still without data
      label: {
        display: true, content: line.label, position: line.axis === 'x' ? 'start' : 'end', backgroundColor: color,
      },
    }];
  }));
}

function typeConfig(canvas, payload) {
  if (BAR_TYPES.includes(payload.type)) {
    return barConfig(canvas, payload);
  }
  return LINE_TYPES.includes(payload.type) ? lineConfig(payload) : pieConfig(canvas, payload);
}

// Chart.js configuration of a payload, for every type but the treemap
// Axes and legends stay in the background: muted text in the font of the
// page, light lines of the value axis only. Labels of the entries stay slanted
// where they do not fit: level, a timeline of days would show every fifth day.
export function quietStyle(canvas, config) {
  const { options } = config;
  const color = canvas ? cssVar(canvas, '--a-color-muted') : undefined;
  const font = { family: getComputedStyle(document.body).fontFamily, size: CHART_FONT_SIZE };
  options.color = color;
  options.font = font;
  if (!options.scales) {
    return;
  }
  const categoryAxis = options.indexAxis === 'y' ? 'y' : 'x';
  options.scales[categoryAxis] = { ...options.scales[categoryAxis] };
  Object.entries(options.scales).forEach(([id, scale]) => {
    const grid = id === categoryAxis ? { display: false } : { color: canvas ? cssVar(canvas, '--a-color-border-light') : undefined };
    scale.grid = { ...grid, ...scale.grid };
    scale.border = { display: false, ...scale.border };
    // Axes resolve their text against defaults of their own, not of the chart
    scale.ticks = { color, font, ...scale.ticks };
    if (scale.title) {
      scale.title = { color, font, ...scale.title };
    }
  });
}

export function chartConfig(canvas, payload) {
  const config = typeConfig(canvas, payload);
  quietStyle(canvas, config);
  config.data.datasets = config.data.datasets.map((dataset, index) => withColors(canvas, dataset, (point) => schemeFill(payload, index, point)));
  if (payload.lines) {
    config.options.plugins.annotation = { annotations: lineAnnotations(canvas, payload) };
  }
  config.options.locale = pageLocale();
  return config;
}

// Level of a day: 0 without value, then one above each bound it exceeds
export function calendarLevel(levels, value) {
  if (!value) {
    return 0;
  }
  return 1 + levels.filter((bound) => value > bound).length;
}

function schemeColors(payload) {
  const [group, name] = (payload.colorSchema || '').split('.');
  return window.Chart?.colorschemes?.[group]?.[name];
}

// First color of the color scheme, as the colorschemes plugin defines it
function schemeColor(payload) {
  const colors = schemeColors(payload);
  return colors ? colors[0] : CALENDAR_FALLBACK_COLOR;
}

// The color the colorschemes plugin gives a point: per slice in a pie, per
// dataset with the fill alpha of bars otherwise
export function schemeFill(payload, datasetIndex, pointIndex) {
  const colors = schemeColors(payload);
  if (!colors) {
    return null;
  }
  if (PIE_TYPES.includes(payload.type)) {
    return colors[pointIndex % colors.length];
  }
  return colorWithAlpha(colors[datasetIndex % colors.length], BAR_FILL_ALPHA);
}

function calendarColor(payload, level) {
  return window.Chart.helpers.color(schemeColor(payload)).alpha(CALENDAR_ALPHAS[level]).rgbString();
}

// Month names that fit next to each other, from the latest month back: a
// name shows only if it ends before the next name shown starts. Names are
// centered on their column, their widths differ by language.
export function calendarMonthLabels(months, columnWidth, textWidth) {
  const labels = {};
  let nextStart = Infinity;
  Object.keys(months).map(Number).sort((a, b) => b - a).forEach((column) => {
    const halfWidth = textWidth(months[column]) / 2;
    const center = (column + 0.5) * columnWidth;
    if (center + halfWidth + CALENDAR_MONTH_GAP <= nextStart) {
      labels[column] = months[column];
      nextStart = center - halfWidth;
    }
  });
  return labels;
}

// Month names measured in the font of the axis at its current width
function fittingMonthLabels(scale, calendar) {
  const { ctx } = scale;
  ctx.save();
  ctx.font = window.Chart.helpers.toFont(scale.options.ticks.font).string;
  const labels = calendarMonthLabels(calendar.months, scale.width / calendar.weeks, (text) => ctx.measureText(text).width);
  ctx.restore();
  return labels;
}

// Ticks at the cells, not between them: the axes reach half a cell beyond
function cellTicks(count) {
  return (scale) => {
    scale.ticks = Array.from({ length: count }, (_value, index) => ({ value: index }));
  };
}

// A grid of rows and columns, e.g. users by day. Each cell has the color of
// its category as the server chose it, a title and lines for its tooltip
// and a link.
export function matrixConfig(canvas, payload) {
  const { matrix } = payload;
  const cellSize = (context, count, axis) => {
    const area = context.chart.chartArea || {};
    const length = (axis === 'x' ? area.width : area.height) || 0;
    return Math.max((length / count) - MATRIX_GAP, 1);
  };

  const config = {
    type: 'matrix',
    data: {
      datasets: [{
        data: matrix.cells,
        backgroundColor: (context) => cssVar(canvas, context.raw?.color || ''),
        borderColor: cssVar(canvas, '--a-color-border-light'),
        borderWidth: 1,
        borderRadius: 3,
        width: (context) => cellSize(context, matrix.columns.length, 'x'),
        height: (context) => cellSize(context, matrix.rows.length, 'y'),
      }],
    },
    options: {
      locale: pageLocale(),
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_event, elements) => {
        if (elements.length > 0) {
          openUrl(matrix.cells[elements[0].index].url);
        }
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => items[0].raw.title,
            label: (context) => context.raw.lines,
          },
        },
      },
      scales: {
        x: {
          type: 'category', labels: matrix.columns, offset: true, grid: { display: false },
        },
        // The first row on top
        y: {
          type: 'category', labels: matrix.rows.slice().reverse(), offset: true, grid: { display: false },
        },
      },
    },
  };
  quietStyle(canvas, config);
  return config;
}

// The days of a year as cells, a column per week and a row per weekday
export function calendarConfig(payload, canvas = null) {
  const { calendar } = payload;
  const level = (context) => calendarLevel(calendar.levels, context.raw?.v);
  const cellSize = (context, count, axis) => {
    const area = context.chart.chartArea || {};
    const length = (axis === 'x' ? area.width : area.height) || 0;
    return Math.max((length / count) - CALENDAR_GAP, 1);
  };

  const config = {
    type: 'matrix',
    data: {
      datasets: [{
        data: calendar.points,
        backgroundColor: (context) => calendarColor(payload, level(context)),
        borderWidth: 0,
        hoverBorderWidth: 1,
        width: (context) => cellSize(context, calendar.weeks, 'x'),
        height: (context) => cellSize(context, 7, 'y'),
      }],
    },
    options: {
      locale: pageLocale(),
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_event, elements) => {
        if (elements.length > 0) {
          openUrl(entryUrl(payload, 0, elements[0].index));
        }
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          displayColors: false,
          callbacks: {
            title: (items) => payload.labels[items[0].dataIndex],
            label: (context) => `${payload.totalLabel}: ${valueText(payload, 0, context.dataIndex)}`,
          },
        },
      },
      scales: {
        x: {
          type: 'linear',
          position: 'top',
          min: -0.5,
          max: calendar.weeks - 0.5,
          afterBuildTicks: (scale) => {
            cellTicks(calendar.weeks)(scale);
            scale.calendarMonths = fittingMonthLabels(scale, calendar);
          },
          grid: { display: false },
          border: { display: false },
          ticks: {
            autoSkip: false,
            maxRotation: 0,
            callback(value) {
              return this.calendarMonths[value] || '';
            },
          },
        },
        y: {
          type: 'linear',
          min: -0.5,
          max: 6.5,
          reverse: true,
          afterBuildTicks: cellTicks(7),
          grid: { display: false },
          border: { display: false },
          ticks: {
            callback: (value) => calendar.weekdays[value] || '',
          },
        },
      },
    },
  };
  quietStyle(canvas, config);
  return config;
}

// Colors of the levels and the values they stand for, below the calendar
export function calendarLegend(payload) {
  const legend = document.createElement('div');
  legend.className = 'additionals-calendar-legend';
  payload.calendar.legend.forEach((text, level) => {
    const item = document.createElement('span');
    const swatch = document.createElement('i');
    swatch.style.backgroundColor = calendarColor(payload, level);
    item.append(swatch, text);
    legend.append(item);
  });
  return legend;
}

// Share in percent in the language of the page, with a decimal for small ones
export function percentText(value, total) {
  const fraction = total > 0 ? value / total : 0;
  return new Intl.NumberFormat(pageLocale(), { style: 'percent', maximumFractionDigits: 1 }).format(fraction);
}

// The tiles of a treemap, largest first. With a name for the rest from the
// server, tiles below 0.01 % of the total merge into it, from two of them on.
export function treemapTiles(payload) {
  const [dataset] = payload.datasets;
  const tiles = payload.labels.map((name, index) => ({
    name,
    // The tile shows its name or the text the server chose for it, e.g. a size
    tile: payload.tileLabels?.[index] ?? name,
    value: dataset.data[index],
    text: valueText(payload, 0, index),
    url: entryUrl(payload, 0, index),
    extra: dataset.tooltips?.[index] || '',
  })).sort((a, b) => b.value - a.value);
  const small = payload.restLabel ? tiles.filter((tile) => tile.value < payload.total * TREEMAP_REST_SHARE) : [];
  if (small.length < 2) {
    return tiles;
  }
  // Sorted by value, the small tiles are the last ones
  const rest = { name: payload.restLabel, tile: payload.restLabel, rest: true, value: small.reduce((sum, tile) => sum + tile.value, 0) };
  return [...tiles.slice(0, tiles.length - small.length), rest];
}

// A word too long for a line in parts, each but the last ending in a hyphen
function splitWord(word, fits) {
  const parts = [];
  let rest = word;
  while (!fits(rest)) {
    let length = rest.length - 1;
    // A part that ends at a hyphen of the word keeps that one
    const part = (end) => (rest[end - 1] === '-' ? rest.slice(0, end) : `${rest.slice(0, end)}-`);
    while (length > 1 && !fits(part(length))) {
      length -= 1;
    }
    if (length <= 1) {
      break;
    }
    parts.push(part(length));
    rest = rest.slice(length);
  }
  return [...parts, rest];
}

// Lines of whole words; with split, a word too long for a line is split
function wrapWords(text, fits, split = false) {
  return text.split(/\s+/).reduce((lines, word) => {
    const joined = lines.length > 0 ? `${lines[lines.length - 1]} ${word}` : null;
    if (joined && fits(joined)) {
      lines[lines.length - 1] = joined;
    } else {
      lines.push(...(split ? splitWord(word, fits) : [word]));
    }
    return lines;
  }, []);
}

// A line ending in an ellipsis, cut where it does not fit with it, without
// a hyphen or space before the ellipsis; null where not even a few
// characters fit
function shortenedLine(line, fits) {
  const minimum = Math.min(TREEMAP_SHORT_MIN_CHARS, line.length);
  for (let { length } = line; length >= minimum; length -= 1) {
    const shortened = `${line.slice(0, length).replace(/[-\s]+$/, '')}…`;
    if (fits(shortened)) {
      return shortened;
    }
  }
  return null;
}

// The wrapped name in at most the given number of lines, the last one ending
// in an ellipsis where text is left out. Where that line cannot hold it, the
// line before ends in it.
function shortenedName(wrapped, rows, fits) {
  const lines = [];
  for (let index = 0; index < Math.min(rows, wrapped.length); index += 1) {
    const line = wrapped[index];
    if (fits(line) && !(index === rows - 1 && wrapped.length > rows)) {
      lines.push(line);
    } else {
      const shortened = shortenedLine(line, fits);
      if (shortened) {
        return [...lines, shortened];
      }
      const previous = lines.length > 0 ? shortenedLine(lines[lines.length - 1], fits) : null;
      return previous ? [...lines.slice(0, -1), previous] : null;
    }
  }
  return lines;
}

// What a tile shows, in this order: the whole name as large as it fits, the
// name in a readable size with long words split and shortened where it is
// still too long, the further lines (the share) alone.
// Smaller text cannot be read, then the tile stays empty (null) and its name
// is in the tooltip.
export function treemapLabelLayout(lines, width, height, measure) {
  const room = width - (2 * TREEMAP_PADDING);
  const rows = (size) => Math.floor((height - (2 * TREEMAP_PADDING)) / (size * TREEMAP_LINE_HEIGHT));
  const fitsAt = (size) => (line) => measure(line, size) <= room;
  const [name, ...others] = lines;
  for (let size = TREEMAP_FONT_MAX; size >= TREEMAP_FONT_MIN; size -= 1) {
    const wrapped = [...wrapWords(String(name), fitsAt(size)), ...others];
    if (wrapped.every(fitsAt(size)) && wrapped.length <= rows(size)) {
      return { size, lines: wrapped };
    }
  }
  const readable = [TREEMAP_FONT_SHORT, TREEMAP_FONT_MIN].map((size) => {
    const fits = fitsAt(size);
    const nameRows = rows(size) - others.length;
    const shortened = nameRows > 0 && others.every(fits) ? shortenedName(wrapWords(String(name), fits, true), nameRows, fits) : null;
    return shortened && { size, lines: [...shortened, ...others], complete: !shortened[shortened.length - 1].endsWith('…'), shown: shortened.join('').replace(/[-…]/g, '').length };
  }).filter(Boolean);
  if (readable.length > 0) {
    // The larger size where the name fits, else the one that shows more of it
    const { size, lines: shown } = readable.find((layout) => layout.complete) ||
      readable.reduce((best, layout) => (layout.shown > best.shown ? layout : best));
    return { size, lines: shown };
  }
  if (others.length > 0 && others.every(fitsAt(TREEMAP_FONT_MIN)) && others.length <= rows(TREEMAP_FONT_MIN)) {
    return { size: TREEMAP_FONT_MIN, lines: others };
  }
  return null;
}

// Width of a text in the font of the page, bold as the name is drawn; the
// smaller share fits then as well. The context is only created when a label
// is laid out, which a page without canvas support never does.
function textMeasure(family) {
  const context = document.createElement('canvas').getContext('2d');
  return (text, size) => {
    context.font = `${TREEMAP_NAME_WEIGHT} ${size}px ${family}`;
    return context.measureText(text).width;
  };
}

// Relative luminance of a color as WCAG defines it, null for notations
// rgbParts does not read
function luminance(color) {
  const parts = rgbParts(color);
  if (!parts) {
    return null;
  }
  const [red, green, blue] = parts.map((part) => part / 255)
    .map((part) => (part <= 0.03928 ? part / 12.92 : ((part + 0.055) / 1.055) ** 2.4));
  return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
}

// Dark text where it has the better contrast to the color; colors of other
// notations get the dark text
export function contrastingText(color, dark, light) {
  const value = luminance(color);
  return value === null || value > LIGHT_LUMINANCE ? dark : light;
}

// A style per line of a tile: the name lines get one, the share below them
// another; a tile showing the share only writes it as a name
function treemapLineStyles(layout, nameStyle, shareStyle) {
  if (!layout) {
    return nameStyle(TREEMAP_FONT_MIN);
  }
  const last = layout.lines.length - 1;
  return layout.lines.map((_line, index) => (index === last && last > 0 ? shareStyle(layout.size) : nameStyle(layout.size)));
}

function treemapTooltip(payload, tile, value) {
  const valueShare = percentText(value, payload.total);
  if (tile.rest) {
    return [`${payload.totalLabel}: ${valueShare}`];
  }
  return [`${payload.totalLabel}: ${tile.text} (${valueShare})`, tile.extra].filter(Boolean);
}

// Each entry as a tile whose area is its share of the total. Canvas shows a
// name with markup as it is, so nothing needs escaping.
export function treemapConfig(canvas, payload) {
  const colors = schemeColors(payload) || [schemeColor(payload)];
  const tileColor = (context) => colors[context.dataIndex % colors.length];
  const family = getComputedStyle(document.body).fontFamily;
  const dark = cssVar(canvas, '--oc-gray-9');
  const light = cssVar(canvas, '--oc-white');
  // The plugin asks for font and text of a tile separately, both come from
  // one layout per tile and size
  const layouts = new Map();
  let measure = null;
  const layout = ({ dataIndex, raw }) => {
    const key = `${dataIndex}:${raw.w}:${raw.h}`;
    if (!layouts.has(key)) {
      measure ||= textMeasure(family);
      const lines = [raw._data.tile, percentText(raw.v, payload.total)];
      layouts.set(key, treemapLabelLayout(lines, raw.w - TREEMAP_INSET, raw.h - TREEMAP_INSET, measure));
    }
    return layouts.get(key);
  };

  return {
    type: 'treemap',
    data: {
      datasets: [{
        tree: treemapTiles(payload),
        key: 'value',
        // Sorted already, so the rest stays last
        unsorted: true,
        spacing: TREEMAP_SPACING,
        borderWidth: 0,
        borderRadius: TREEMAP_RADIUS,
        backgroundColor: tileColor,
        hoverBackgroundColor: (context) => colorWithAlpha(tileColor(context), TREEMAP_HOVER_ALPHA),
        labels: {
          display: true,
          overflow: 'hidden',
          padding: TREEMAP_PADDING,
          align: 'left',
          position: 'top',
          color: (context) => {
            const text = contrastingText(tileColor(context), dark, light);
            return treemapLineStyles(layout(context), () => text, () => colorWithAlpha(text, TREEMAP_SHARE_ALPHA));
          },
          font: (context) => treemapLineStyles(
            layout(context),
            (size) => ({ family, size, weight: TREEMAP_NAME_WEIGHT }),
            (size) => ({ family, size: Math.max(TREEMAP_FONT_MIN, Math.round(size * TREEMAP_SHARE_SCALE)) }),
          ),
          formatter: (context) => layout(context)?.lines ?? '',
        },
      }],
    },
    options: {
      locale: pageLocale(),
      responsive: true,
      maintainAspectRatio: false,
      // The tile at its final place: Chart.js looks at the current one, where a
      // click while the tiles grow finds none. The rest has no list of its own.
      onClick: (event, _elements, chart) => {
        const [element] = chart.getElementsAtEventForMode(event, 'nearest', { intersect: true }, true);
        const tile = element ? chart.data.datasets[0].data[element.index]?._data : null;
        openUrl(tile && !tile.rest ? tile.url : null);
      },
      plugins: {
        legend: { display: false },
        // The tiles have their colors already
        colorschemes: false,
        tooltip: {
          displayColors: false,
          callbacks: {
            title: (items) => items[0].raw._data.name,
            label: (context) => treemapTooltip(payload, context.raw._data, context.raw.v),
          },
        },
      },
    },
  };
}

// The hierarchy of a sankey as flows of Chart.js: each flow as thick as the
// entries without children below its target, so a parent is as thick as its
// children, and each level in a column of its own. The plugin places the
// nodes itself; that keeps every tree free of crossing flows. The children of
// a parent form a family, numbered in the order of the tree.
function sankeyTree(payload) {
  const { nodes, links } = payload.sankey;
  const children = new Map();
  links.forEach(({ source, target }) => {
    children.set(String(source), [...(children.get(String(source)) || []), String(target)]);
  });
  const leaves = new Map();
  const leavesBelow = (key) => {
    if (!leaves.has(key)) {
      const below = children.get(key) || [];
      leaves.set(key, below.length > 0 ? below.reduce((sum, child) => sum + leavesBelow(child), 0) : 1);
    }
    return leaves.get(key);
  };
  const column = {};
  const family = new Map();
  let families = 0;
  const place = (key, depth) => {
    column[key] = depth;
    const below = children.get(key) || [];
    if (below.length > 0) {
      const index = families;
      families += 1;
      below.forEach((child) => family.set(child, index));
    }
    below.forEach((child) => place(child, depth + 1));
  };
  const targets = new Set(links.map(({ target }) => String(target)));
  nodes.map(({ id }) => String(id)).filter((key) => !targets.has(key)).forEach((key) => place(key, 0));
  return {
    nodes: new Map(nodes.map((node) => [String(node.id), node])),
    flows: links.map(({ source, target }) => ({ from: String(source), to: String(target), flow: leavesBelow(String(target)) })),
    column,
    family,
  };
}

// The node at a point. The plugin knows flows only, so a node is found at the
// ends of its flows: an incoming one ends at its left edge, an outgoing one
// starts at its right edge. Flows at their final place, they may still move.
export function sankeyNodeAt(chart, x, y) {
  const flows = chart.data.datasets[0].data;
  const elements = chart.getDatasetMeta(0).data;
  for (let index = 0; index < elements.length; index += 1) {
    const flow = elements[index].getProps(['x', 'x2', 'y', 'y2', 'height'], true);
    const bottom = Math.max(flow.height, SANKEY_MIN_HIT_HEIGHT);
    const node = [{ key: flows[index].to, left: flow.x2, top: flow.y2 },
      { key: flows[index].from, left: flow.x - SANKEY_NODE_WIDTH, top: flow.y }]
      .find(({ left, top }) => x >= left - SANKEY_HIT_TOLERANCE && x <= left + SANKEY_NODE_WIDTH + SANKEY_HIT_TOLERANCE &&
        y >= top - SANKEY_HIT_TOLERANCE && y <= top + bottom + SANKEY_HIT_TOLERANCE);
    if (node) {
      return { key: node.key, index };
    }
  }
  return null;
}

// Interaction mode of a sankey: the flow at a point, else a flow of the node
// there. The chart remembers the node for tooltip and click.
export function sankeyItemsAt(chart, event) {
  const flows = chart.getElementsAtEventForMode(event, 'nearest', { intersect: true }, true);
  if (flows.length > 0) {
    chart.$additionalsSankeyNode = null;
    return flows.slice(0, 1);
  }
  const node = sankeyNodeAt(chart, event.x, event.y);
  chart.$additionalsSankeyNode = node ? node.key : null;
  return node ? [{ element: chart.getDatasetMeta(0).data[node.index], datasetIndex: 0, index: node.index }] : [];
}

// A node opens itself, a flow its target: in a tree the node it leads to
function sankeyUrl(chart, nodes, items) {
  if (items.length === 0) {
    return null;
  }
  const key = chart.$additionalsSankeyNode || chart.data.datasets[0].data[items[0].index].to;
  return nodes.get(key)?.url || null;
}

function registerSankeyInteraction() {
  Chart.Interaction.modes[SANKEY_MODE] = sankeyItemsAt;
  Chart.Tooltip.positioners[SANKEY_POSITIONER] = (_elements, position) => position;
}

// A hierarchy as flows from the left, e.g. projects and their subprojects.
// The nodes carry no names, those are in the tooltip.
export function sankeyConfig(canvas, payload) {
  const tree = sankeyTree(payload);
  const scheme = schemeColors(payload) || [schemeColor(payload)];
  // Thin flows in the light colors of a scheme vanish on white, e.g. the
  // yellow of YlGnBu; a scheme of light colors only keeps them all
  const readable = scheme.filter((color) => (luminance(color) ?? 0) <= SANKEY_MAX_LUMINANCE);
  const colors = readable.length > 0 ? readable : scheme;
  const rootColor = cssVar(canvas, '--oc-gray-6');
  // One color per family: at every level it shows which projects belong
  // together, also where one branch holds almost all of them
  const nodeColor = (key) => (tree.family.has(key) ? colors[tree.family.get(key) % colors.length] : rootColor);
  const name = (key) => tree.nodes.get(key)?.name || '';
  const flowDelay = Math.min(SANKEY_FLOW_DELAY, SANKEY_FLOWS_DELAY / Math.max(tree.flows.length, 1));

  return {
    type: 'sankey',
    data: {
      datasets: [{
        data: tree.flows,
        column: tree.column,
        nodePadding: SANKEY_NODE_PADDING,
        nodeLabels: { display: false },
        nodeWidth: SANKEY_NODE_WIDTH,
        borderWidth: 0,
        size: 'max',
        colorMode: 'gradient',
        alpha: SANKEY_FLOW_ALPHA,
        // The plugin delays each flow by 20 ms, a large tree took seconds to appear
        animations: {
          progress: {
            delay: (context) => (context.type === 'data' ? (context.parsed.x * SANKEY_COLUMN_DELAY) + (context.dataIndex * flowDelay) : undefined),
          },
        },
        colorFrom: (context) => nodeColor(context.raw?.from),
        colorTo: (context) => nodeColor(context.raw?.to),
      }],
    },
    options: {
      locale: pageLocale(),
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: SANKEY_MODE, intersect: true },
      plugins: {
        legend: { display: false },
        // The flows have their colors already
        colorschemes: false,
        tooltip: {
          position: SANKEY_POSITIONER,
          displayColors: false,
          callbacks: {
            title: ([item]) => (item.chart.$additionalsSankeyNode
              ? name(item.chart.$additionalsSankeyNode)
              : `${name(item.raw.from)} → ${name(item.raw.to)}`),
            label: () => [],
          },
        },
      },
    },
    // The nodes of the last column lie right of the chart area, where Chart.js
    // calls no onClick, so clicks and the pointer are handled for the whole canvas
    plugins: [{
      id: 'additionalsSankeyNodes',
      afterEvent: (chart, { event }) => {
        if (event.type !== 'click' && event.type !== 'mousemove') {
          return;
        }
        const url = sankeyUrl(chart, tree.nodes, sankeyItemsAt(chart, event));
        if (event.type === 'click') {
          openUrl(url);
        } else {
          chart.canvas.style.cursor = url ? 'pointer' : '';
        }
      },
    }],
  };
}

class AdditionalsChartController extends Controller {
  static targets = ['canvas'];

  static values = {
    payload: Object,
  };

  connect() {
    // A block that disconnects and connects again while a library is still
    // loading must not draw twice, the draw of the older connection is void
    this.connection = {};
    const payload = this.payloadValue;
    // Without a plugin the block stays empty, the reason belongs in the console
    if (payload.type === 'treemap' && this.hasCanvasTarget) {
      this.drawTreemap(payload).catch((error) => console.error(error));
    } else if (payload.type === 'sankey' && this.hasCanvasTarget) {
      this.drawSankey(payload).catch((error) => console.error(error));
    } else if (payload.type === 'matrix' && this.hasCanvasTarget) {
      this.drawMatrix(payload).catch((error) => console.error(error));
    } else if (payload.type === 'calendar' && this.hasCanvasTarget) {
      this.drawCalendar(payload).catch((error) => console.error(error));
    } else if (payload.lines && this.hasCanvasTarget) {
      this.drawWithLines(payload).catch((error) => console.error(error));
    } else if (this.hasCanvasTarget) {
      this.chart = new Chart(this.canvasTarget, chartConfig(this.canvasTarget, payload));
    }
  }

  // Lines across the chart need the annotation plugin, which not every page loads
  async drawWithLines(payload) {
    if (await this.loaded('chartjs_annotation')) {
      this.chart = new Chart(this.canvasTarget, chartConfig(this.canvasTarget, payload));
    }
  }

  disconnect() {
    this.connection = null;
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
    this.legend?.remove();
    this.legend = null;
  }

  // Whether the library is there and the block still the one it was loaded
  // for: it may have been reloaded or removed in the meantime
  async loaded(library) {
    const { connection } = this;
    await AdditionalsHelpers.loadLibrary(library);
    return this.element.isConnected && this.connection === connection;
  }

  async drawTreemap(payload) {
    if (await this.loaded('chartjs_treemap')) {
      this.chart = new Chart(this.canvasTarget, treemapConfig(this.canvasTarget, payload));
    }
  }

  async drawMatrix(payload) {
    if (await this.loaded('chartjs_matrix')) {
      this.chart = new Chart(this.canvasTarget, matrixConfig(this.canvasTarget, payload));
    }
  }

  async drawCalendar(payload) {
    if (!await this.loaded('chartjs_matrix')) {
      return;
    }
    this.chart = new Chart(this.canvasTarget, calendarConfig(payload, this.canvasTarget));
    this.legend = calendarLegend(payload);
    this.element.after(this.legend);
  }

  async drawSankey(payload) {
    if (await this.loaded('chartjs_sankey')) {
      registerSankeyInteraction();
      this.chart = new Chart(this.canvasTarget, sankeyConfig(this.canvasTarget, payload));
    }
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-chart', AdditionalsChartController);
}

export default AdditionalsChartController;
