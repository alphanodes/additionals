/* global Chart, ChartDataLabels */
import { Controller } from '@hotwired/stimulus';

// Draws a chart block from the payload the server renders into a data
// attribute (AdditionalsQueryChart#payload), so no value is interpolated into
// JavaScript. Chart.js draws doughnut, pie and bars, d3plus the treemap. A
// click on a slice opens the list filtered by its value.
//
// Chart.js and its plugins come from the libraries of the block. d3plus is
// large and only needed for a treemap, so the controller loads it on demand
// through the library registry.
// Blocks loaded asynchronously connect like any other element, and a reloaded
// or removed block releases its chart.

const BAR_TYPES = ['bar_horizontal', 'bar_vertical'];
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

function barConfig(payload) {
  const horizontal = payload.type === 'bar_horizontal';
  const valueAxis = horizontal ? 'x' : 'y';

  return {
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
}

// Chart.js configuration of a payload, for every type but the treemap
export function chartConfig(canvas, payload) {
  return BAR_TYPES.includes(payload.type) ? barConfig(payload) : pieConfig(canvas, payload);
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
    } else if (this.hasCanvasTarget) {
      this.chart = new Chart(this.canvasTarget, chartConfig(this.canvasTarget, payload));
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
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
