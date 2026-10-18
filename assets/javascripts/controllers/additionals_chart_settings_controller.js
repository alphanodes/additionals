import { Controller } from '@hotwired/stimulus';

// Settings form of a chart block (AdditionalsQueryChart): offers only the
// settings that apply to the chosen field and display type, and tells why the
// others do not. A date field is a timeline, summed up per interval, drawn as
// line, area, bars or table, and always in the order of time with dates only.
// Doughnut, pie and treemap show no series, so neither a split nor a
// comparison; a split replaces the comparison. A period applies to the other
// fields only, the previous one is a comparison of a block with period.
// A number field forms classes in the order of their values, with bounds.
//
// The server falls back the same way for settings saved before (see
// AdditionalsQueryChart#chart_type), the form only hides or disables what
// would not apply.

// The display types of a timeline and of a category without line and area
// fall back to these, like the server does
const TIMELINE_FALLBACK = 'line';
const CATEGORY_FALLBACK = 'bar_vertical';
const CALENDAR = 'calendar';

function hide(element, hidden) {
  element.hidden = hidden;
}

class AdditionalsChartSettingsController extends Controller {
  static targets = ['groupBy', 'interval', 'classes', 'chartType', 'tile', 'series', 'sharesNote', 'order',
    'maxEntries', 'showEmpty', 'periodSelect', 'periodInfo', 'splitSelect', 'compareSelect', 'compareInfo',
    'compareSplitInfo'];

  static values = {
    timelineGroups: Array,
    numberGroups: Array,
    timelineTypes: Array,
    timelineOnlyTypes: Array,
    seriesTypes: Array,
    previousPeriod: String,
    noTimelineReason: String,
    timelineOnlyReason: String,
  };

  connect() {
    this.update();
  }

  update() {
    const timeline = this.timeline();
    const classes = this.hasGroupByTarget && this.numberGroupsValue.includes(this.groupByTarget.value);
    this.offerChartTypes(timeline);
    if (this.hasIntervalTarget) {
      // A calendar shows days
      hide(this.intervalTarget, !timeline || this.chartType() === CALENDAR);
    }
    if (this.hasClassesTarget) {
      hide(this.classesTarget, !classes);
    }
    // Periods and classes keep the order of their values
    this.orderTargets.forEach((element) => hide(element, timeline || classes));
    this.maxEntriesTargets.forEach((element) => hide(element, classes));
    this.showEmptyTargets.forEach((element) => hide(element, timeline));
    this.offerPeriod(timeline);
    this.offerPreviousPeriod(timeline);

    const series = this.seriesTypesValue.includes(this.chartType());
    this.seriesTargets.forEach((element) => hide(element, !series));
    this.sharesNoteTargets.forEach((element) => hide(element, series));
    this.offerCompare();
  }

  chartType() {
    return this.chartTypeTargets.find((radio) => radio.checked)?.value;
  }

  timeline() {
    return this.hasGroupByTarget && this.timelineGroupsValue.includes(this.groupByTarget.value);
  }

  // A timeline shows the periods itself
  offerPeriod(timeline) {
    if (this.hasPeriodSelectTarget) {
      this.periodSelectTarget.disabled = timeline;
    }
    if (this.hasPeriodInfoTarget) {
      hide(this.periodInfoTarget, !timeline);
    }
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

  // A split replaces the comparison
  offerCompare() {
    if (!this.hasCompareSelectTarget) {
      return;
    }

    const split = this.hasSplitSelectTarget && this.splitSelectTarget.value !== '';
    this.compareSelectTarget.disabled = split;
    if (this.hasCompareInfoTarget) {
      hide(this.compareInfoTarget, split);
    }
    if (this.hasCompareSplitInfoTarget) {
      hide(this.compareSplitInfoTarget, !split);
    }
  }

  // Types that do not fit stay visible, disabled and with the reason as tooltip
  offerChartTypes(timeline) {
    const reason = timeline ? this.noTimelineReasonValue : this.timelineOnlyReasonValue;
    this.chartTypeTargets.forEach((radio) => {
      const offered = timeline
        ? this.timelineTypesValue.includes(radio.value)
        : !this.timelineOnlyTypesValue.includes(radio.value);
      radio.disabled = !offered;
      this.markTile(radio.closest('label'), offered ? null : reason);
    });

    const checked = this.chartTypeTargets.find((radio) => radio.checked);
    if (!checked || checked.disabled) {
      const fallback = timeline ? TIMELINE_FALLBACK : CATEGORY_FALLBACK;
      const radio = this.chartTypeTargets.find((item) => item.value === fallback);
      if (radio) {
        radio.checked = true;
      }
    }
    this.tileTargets.forEach((tile) => {
      tile.classList.toggle('selected', tile.querySelector('input').checked);
    });
  }

  markTile(tile, reason) {
    if (!tile) {
      return;
    }

    const $tile = typeof $ !== 'undefined' && $.fn.tooltip ? $(tile) : null;
    if ($tile?.tooltip('instance')) {
      $tile.tooltip('destroy');
    }
    tile.classList.toggle('disabled', reason !== null);
    if (reason === null) {
      tile.removeAttribute('title');
      return;
    }

    tile.title = reason;
    $tile?.tooltip({ show: { delay: 400 }, position: { my: 'center bottom-5', at: 'center top' } });
  }
}

if (typeof window !== 'undefined' && window.Stimulus) {
  window.Stimulus.register('additionals-chart-settings', AdditionalsChartSettingsController);
}

export default AdditionalsChartSettingsController;
