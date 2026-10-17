/* global Chart, ChartDataLabels */
import { Controller } from '@hotwired/stimulus';

// Draws a chart block from the payload the server renders into a data
// attribute (AdditionalsQueryChart#payload), so no value is interpolated into
// JavaScript. Chart.js draws doughnut, pie, bars, lines and areas, d3plus the
// treemap. A click on a slice opens the list filtered by its value.
//
// Chart.js and its plugins come from the libraries of the block. d3plus, only
// needed for a treemap, and the matrix plugin, only needed for a calendar,
// are loaded on demand through the library registry.
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
// Bars of the color scheme are filled with its colors at this alpha
const BAR_FILL_ALPHA = 0.8;
const CALENDAR_GAP = 2;
// Space between two month names
const CALENDAR_MONTH_GAP = 4;
// Gap between the cells of a matrix of rows and columns
const MATRIX_GAP = 4;

// Reads a CSS custom property from an element. Canvas cannot resolve var().
function cssVar(el, name) {
  return getComputedStyle(el).getPropertyValue(name).trim();
}

function openUrl(url) {
  if (url) {
    window.open(url);
  }
}

// Values as the table of values shows them, e.g. hours in the format of the
// user. Payloads without texts show the plain number.
function valueText(payload, datasetIndex, index) {
  const texts = payload.valueTexts && payload.valueTexts[datasetIndex];
  return texts ? texts[index] : String(payload.datasets[datasetIndex].data[index]);
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

// Ticks of a value axis: counts in whole steps, not 0.5 between 0 and 1
export function valueTicks(payload) {
  const counts = payload.datasets.every((dataset) => dataset.data.every(Number.isInteger));
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
          content: [payload.totalText || String(payload.total), payload.totalLabel],
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

  const textWidth = estimatedTextWidth(valueText(payload, context.datasetIndex, context.dataIndex));
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
          return `${text} (${partShare(payload, context.datasetIndex, context.dataIndex)}%)`;
        },
      },
    },
    datalabels: {
      anchor: 'center',
      align: 'center',
      padding: VALUE_LABEL_PADDING,
      display: (context) => showValueLabel(payload, context) && valueFitsInPart(payload, context, horizontal),
      formatter: (_value, context) => (payload.percent
        ? `${partShare(payload, context.datasetIndex, context.dataIndex)} %`
        : valueText(payload, context.datasetIndex, context.dataIndex)),
    },
  };
}

// Share of a part in its bar, from the values of the payload
function partShare(payload, datasetIndex, index) {
  return share(payload.datasets[datasetIndex].data[index], rowTotal(payload, index));
}

// Parts as shares of their bar, each bar up to 100 %, e.g. to compare the
// estimated part of few open with many closed issues
export function shareDatasets(payload) {
  return payload.datasets.map((dataset) => ({
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
          labels: { sort: byDatasetIndex },
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
  config.options.plugins.tooltip.itemSort = byDatasetIndex;
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
  if (payload.percent) {
    const axis = config.options.scales[valueAxis];
    axis.max = 100;
    axis.ticks = { callback: (value) => `${value} %` };
  }

  return config;
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
  const rgb = /^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/.exec(color || '');
  if (rgb) {
    return `rgba(${rgb[1]}, ${rgb[2]}, ${rgb[3]}, ${alpha})`;
  }
  const hex = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(color || '');
  if (!hex) {
    return color;
  }
  const digits = hex[1].length === 3 ? hex[1].replace(/./g, '$&$&') : hex[1];
  const [red, green, blue] = digits.match(/../g).map((part) => parseInt(part, 16));
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
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

function byDatasetIndex(a, b) {
  return a.datasetIndex - b.datasetIndex;
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
    order: dataset.onTop ? -1 : 0,
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
          display: payload.datasets.length > 1,
          position: 'bottom',
          labels: { sort: byDatasetIndex, generateLabels: legendLabels },
        },
        colorschemes: {
          scheme: payload.colorSchema,
          fillAlpha: 0.5,
        },
        tooltip: {
          itemSort: byDatasetIndex,
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
export function chartConfig(canvas, payload) {
  const config = typeConfig(canvas, payload);
  config.data.datasets = config.data.datasets.map((dataset, index) => withColors(canvas, dataset, (point) => schemeFill(payload, index, point)));
  if (payload.lines) {
    config.options.plugins.annotation = { annotations: lineAnnotations(canvas, payload) };
  }
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

// The days of a year as cells, a column per week and a row per weekday
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

  return {
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
}

export function calendarConfig(payload) {
  const { calendar } = payload;
  const level = (context) => calendarLevel(calendar.levels, context.raw?.v);
  const cellSize = (context, count, axis) => {
    const area = context.chart.chartArea || {};
    const length = (axis === 'x' ? area.width : area.height) || 0;
    return Math.max((length / count) - CALENDAR_GAP, 1);
  };

  return {
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

// Tiles below a tiny share d3plus merges into one, its fields become lists
function isTreemapRest(d) {
  return Boolean(d._isAggregation) || typeof d.name !== 'string';
}

function treemapName(payload, d) {
  return isTreemapRest(d) ? payload.restLabel || '' : d.name;
}

function treemapTooltip(payload, d) {
  const value = `${payload.totalLabel}: `;
  if (isTreemapRest(d)) {
    return escapeHtml(`${value}${share(d.value, payload.total)}%`);
  }
  return [`${value}${d.text} (${share(d.value, payload.total)}%)`, d.extra]
    .filter(Boolean).map(escapeHtml).join('<br>');
}

export function renderTreemap(element, payload) {
  const data = payload.labels.map((label, index) => ({
    // Two versions "1.0" or users of the same name stay separate tiles
    id: index,
    name: label,
    text: valueText(payload, 0, index),
    value: payload.datasets[0].data[index],
    // not "url": d3plus fetches a field of that name as data
    link: entryUrl(payload, 0, index),
    extra: payload.datasets[0].tooltips?.[index] || '',
  }));

  return new window.d3plus.Treemap()
    .data(data)
    .groupBy('id')
    .sum('value')
    // d3plus labels the rest itself, in English otherwise
    .thresholdName(() => payload.restLabel || '')
    // d3plus v4 takes tile labels from .label(), shapeConfig would show the id
    .label((d) => treemapName(payload, d))
    .select(element)
    .legend(false)
    .zoom(false)
    .search(false)
    .tableView(false)
    // The rest has no list of its own
    .on('click', (d) => openUrl(d && !isTreemapRest(d) ? d.link : null))
    .tooltipConfig({
      // d3plus writes its tooltip as HTML, unlike Chart.js which draws on a canvas
      title: (d) => escapeHtml(treemapName(payload, d)),
      body: (d) => treemapTooltip(payload, d),
      // d3plus adds an own, untranslated share row otherwise
      tbody: [],
    })
    .render();
}

class AdditionalsChartController extends Controller {
  static targets = ['canvas'];

  static values = {
    payload: Object,
  };

  connect() {
    const payload = this.payloadValue;
    if (payload.type === 'treemap') {
      // Without d3plus the block stays empty, the reason belongs in the console
      this.drawTreemap(payload).catch((error) => console.error(error));
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
    await AdditionalsHelpers.loadLibrary('chartjs_annotation');
    if (this.element.isConnected) {
      this.chart = new Chart(this.canvasTarget, chartConfig(this.canvasTarget, payload));
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
    this.legend?.remove();
    this.legend = null;
  }

  async drawMatrix(payload) {
    await AdditionalsHelpers.loadLibrary('chartjs_matrix');
    // The block may have been reloaded while the matrix plugin was loading
    if (this.element.isConnected) {
      this.chart = new Chart(this.canvasTarget, matrixConfig(this.canvasTarget, payload));
    }
  }

  async drawCalendar(payload) {
    await AdditionalsHelpers.loadLibrary('chartjs_matrix');
    // The block may have been reloaded while the matrix plugin was loading
    if (!this.element.isConnected) {
      return;
    }
    this.chart = new Chart(this.canvasTarget, calendarConfig(payload));
    this.legend = calendarLegend(payload);
    this.element.after(this.legend);
  }

  async drawTreemap(payload) {
    await AdditionalsHelpers.loadLibrary('d3plus');
    // The block may have been reloaded while d3plus was loading
    if (this.element.isConnected) {
      renderTreemap(this.element, payload);
    }
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-chart', AdditionalsChartController);
}

export default AdditionalsChartController;
