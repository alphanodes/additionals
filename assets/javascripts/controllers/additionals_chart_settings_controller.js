import { Controller } from '@hotwired/stimulus';

// Settings form of a chart block (AdditionalsQueryChart): offers only the
// settings that apply to the chosen field and display type. A date field is
// a timeline, summed up per interval, drawn as line, area, bars or table, and
// always in the order of time with dates only. Doughnut, pie and treemap show
// no series, so neither a split nor a comparison.
//
// The server falls back the same way for settings saved before (see
// AdditionalsQueryChart#chart_type), the form only hides what would not apply.

// The display types of a timeline and of a category without line and area
// fall back to these, like the server does
const TIMELINE_FALLBACK = 'line';
const CATEGORY_FALLBACK = 'bar_vertical';

function hide(element, hidden) {
  element.hidden = hidden;
}

class AdditionalsChartSettingsController extends Controller {
  static targets = ['groupBy', 'interval', 'chartType', 'series', 'category'];

  static values = {
    timelineGroups: Array,
    lineTypes: Array,
    seriesTypes: Array,
  };

  connect() {
    this.update();
  }

  update() {
    const timeline = this.timeline();
    if (this.hasIntervalTarget) {
      hide(this.intervalTarget, !timeline);
    }
    this.categoryTargets.forEach((element) => hide(element, timeline));

    if (this.hasChartTypeTarget) {
      this.offerChartTypes(timeline);
      const series = this.seriesTypesValue.includes(this.chartTypeTarget.value);
      this.seriesTargets.forEach((element) => hide(element, !series));
    }
  }

  timeline() {
    return this.hasGroupByTarget && this.timelineGroupsValue.includes(this.groupByTarget.value);
  }

  // Safari ignores hidden options of a select, disabled ones cannot be chosen there either
  offerChartTypes(timeline) {
    const select = this.chartTypeTarget;
    Array.from(select.options).forEach((option) => {
      const offered = timeline
        ? this.seriesTypesValue.includes(option.value)
        : !this.lineTypesValue.includes(option.value);
      option.hidden = !offered;
      option.disabled = !offered;
    });

    if (select.selectedOptions[0]?.disabled) {
      select.value = timeline ? TIMELINE_FALLBACK : CATEGORY_FALLBACK;
    }
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-chart-settings', AdditionalsChartSettingsController);
}

export default AdditionalsChartSettingsController;
