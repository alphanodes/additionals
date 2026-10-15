import { Controller } from '@hotwired/stimulus';

// Settings form of a chart block (AdditionalsQueryChart): offers only the
// settings that apply to the chosen field and display type. A date field is
// a timeline, summed up per interval, drawn as line, area, bars or table, and
// always in the order of time with dates only. Doughnut, pie and treemap show
// no series, so neither a split nor a comparison. A period applies to the
// other fields only, the previous one is a comparison of a block with period.
// A number field forms classes in the order of their values, with bounds.
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
  static targets = ['groupBy', 'interval', 'classes', 'chartType', 'series', 'order', 'maxEntries', 'showEmpty',
    'period', 'periodSelect', 'compareSelect'];

  static values = {
    timelineGroups: Array,
    numberGroups: Array,
    lineTypes: Array,
    seriesTypes: Array,
    previousPeriod: String,
  };

  connect() {
    this.update();
  }

  update() {
    const timeline = this.timeline();
    const classes = this.hasGroupByTarget && this.numberGroupsValue.includes(this.groupByTarget.value);
    if (this.hasIntervalTarget) {
      hide(this.intervalTarget, !timeline);
    }
    if (this.hasClassesTarget) {
      hide(this.classesTarget, !classes);
    }
    // Periods and classes keep the order of their values
    this.orderTargets.forEach((element) => hide(element, timeline || classes));
    this.maxEntriesTargets.forEach((element) => hide(element, classes));
    this.showEmptyTargets.forEach((element) => hide(element, timeline));
    if (this.hasPeriodTarget) {
      hide(this.periodTarget, timeline);
    }
    this.offerPreviousPeriod(timeline);

    if (this.hasChartTypeTarget) {
      this.offerChartTypes(timeline);
      const series = this.seriesTypesValue.includes(this.chartTypeTarget.value);
      this.seriesTargets.forEach((element) => hide(element, !series));
    }
  }

  timeline() {
    return this.hasGroupByTarget && this.timelineGroupsValue.includes(this.groupByTarget.value);
  }

  offerPreviousPeriod(timeline) {
    if (!this.hasCompareSelectTarget) {
      return;
    }

    const select = this.compareSelectTarget;
    const option = Array.from(select.options).find((item) => item.value === this.previousPeriodValue);
    if (!option) {
      return;
    }

    const offered = !timeline && this.hasPeriodSelectTarget && this.periodSelectTarget.value !== '';
    option.hidden = !offered;
    option.disabled = !offered;
    if (!offered && select.value === this.previousPeriodValue) {
      select.value = '';
    }
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
