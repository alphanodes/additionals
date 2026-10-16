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
const LINE_POINT_RADIUS = 3;
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
const CALENDAR_GAP = 2;
// Space between two month names
const CALENDAR_MONTH_GAP = 4;

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

function estimatedTextWidth(text) {
  return Math.ceil(text.length * VALUE_LABEL_FONT_SIZE * DIGIT_WIDTH_FACTOR);
}

function longestValueWidth(payload) {
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
  return payload.datasets.reduce((sum, dataset) => sum + (dataset.data[index] || 0), 0);
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
        label: (context) => {
          const percentage = share(context.raw, rowTotal(payload, context.dataIndex));
          return `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)} (${percentage}%)`;
        },
      },
    },
    datalabels: {
      anchor: 'center',
      align: 'center',
      padding: VALUE_LABEL_PADDING,
      display: (context) => context.dataset.data[context.dataIndex] !== 0 && valueFitsInPart(payload, context, horizontal),
      formatter: (_value, context) => valueText(payload, context.datasetIndex, context.dataIndex),
    },
  };
}

function barConfig(payload) {
  const horizontal = payload.type === 'bar_horizontal';
  const valueAxis = horizontal ? 'x' : 'y';
  const stacked = payload.stacked ? stackedOptions(payload, horizontal) : null;

  const config = {
    type: 'bar',
    data: {
      labels: payload.labels,
      datasets: payload.datasets,
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
          title: {
            display: true,
            text: payload.totalLabel,
          },
        },
      },
      plugins: {
        legend: {
          display: payload.datasets.length > 1,
          // The room for the values above vertical bars lies above the
          // legend, the values would run into it
          position: horizontal ? 'top' : 'bottom',
        },
        colorschemes: {
          scheme: payload.colorSchema,
          fillAlpha: 0.8,
        },
        tooltip: {
          callbacks: {
            label: (context) => `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)}`,
          },
        },
        datalabels: {
          anchor: 'end',
          align: 'end',
          padding: VALUE_LABEL_PADDING,
          rotation: (context) => (horizontal ? 0 : valueLabelRotation(payload, context)),
          display: (context) => context.dataset.data[context.dataIndex] !== 0,
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

// A timeline: one line or area per series, the tooltip names all series of a period
function lineConfig(payload) {
  const datasets = payload.datasets.map((dataset, index) => ({
    ...dataset,
    fill: lineFill(payload, index),
    pointRadius: payload.labels.length > MAX_PERIODS_WITH_POINTS ? 0 : LINE_POINT_RADIUS,
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
          title: {
            display: true,
            text: payload.totalLabel,
          },
        },
      },
      plugins: {
        legend: {
          display: payload.datasets.length > 1,
          position: 'bottom',
        },
        colorschemes: {
          scheme: payload.colorSchema,
          fillAlpha: 0.5,
        },
        tooltip: {
          callbacks: {
            label: (context) => `${context.dataset.label}: ${valueText(payload, context.datasetIndex, context.dataIndex)}`,
          },
        },
      },
    },
  };
}

// Chart.js configuration of a payload, for every type but the treemap
export function chartConfig(canvas, payload) {
  if (BAR_TYPES.includes(payload.type)) {
    return barConfig(payload);
  }
  return LINE_TYPES.includes(payload.type) ? lineConfig(payload) : pieConfig(canvas, payload);
}

// Level of a day: 0 without value, then one above each bound it exceeds
export function calendarLevel(levels, value) {
  if (!value) {
    return 0;
  }
  return 1 + levels.filter((bound) => value > bound).length;
}

// First color of the color scheme, as the colorschemes plugin defines it
function schemeColor(payload) {
  const [group, name] = (payload.colorSchema || '').split('.');
  const colors = window.Chart?.colorschemes?.[group]?.[name];
  return colors ? colors[0] : CALENDAR_FALLBACK_COLOR;
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

export function renderTreemap(element, payload) {
  const data = payload.labels.map((label, index) => ({
    // Two versions "1.0" or users of the same name stay separate tiles
    id: index,
    name: label,
    text: valueText(payload, 0, index),
    value: payload.datasets[0].data[index],
    // not "url": d3plus fetches a field of that name as data
    link: entryUrl(payload, 0, index),
  }));

  return new window.d3plus.Treemap()
    .data(data)
    .groupBy('id')
    .sum('value')
    // d3plus v4 takes tile labels from .label(), shapeConfig would show the id
    .label((d) => d.name)
    .select(element)
    .legend(false)
    .zoom(false)
    .search(false)
    .tableView(false)
    .on('click', (d) => openUrl(d && d.link))
    .tooltipConfig({
      // d3plus writes its tooltip as HTML, unlike Chart.js which draws on a canvas
      title: (d) => escapeHtml(d.name),
      body: (d) => escapeHtml(`${payload.totalLabel}: ${d.text} (${share(d.value, payload.total)}%)`),
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
    } else if (payload.type === 'calendar' && this.hasCanvasTarget) {
      this.drawCalendar(payload).catch((error) => console.error(error));
    } else if (this.hasCanvasTarget) {
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
