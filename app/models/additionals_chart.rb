# frozen_string_literal: true

class AdditionalsChart
  include ActiveRecord::Sanitization
  include Redmine::I18n

  attr_accessor :project, :query

  CHART_DEFAULT_HEIGHT = 350
  CHART_HEADER_HEIGHT = 80
  # Icon of the title by type, bars for all others
  CHART_ICONS = { 'doughnut' => 'chart-pie', 'pie' => 'chart-pie', 'line' => 'chart-line',
                  'area' => 'chart-area', 'calendar' => 'calendar', 'table' => 'table' }.freeze

  class << self
    # Cheap pre-check before async fetch — drives the lazy-load min-height.
    # Subclasses should override with a single EXISTS query. Default is
    # false (conservative — no min-height, layout stays compact for unknown
    # charts; lazy may not trigger but no empty-block sizing risk).
    def chart_data_present?(project:) # rubocop:disable Lint/UnusedMethodArgument
      false
    end

    # Total box height expected once the chart is rendered (canvas + header).
    # Used by render_async to set min-height so the lazy observer can see
    # the final layout before content loads.
    def chart_height
      CHART_DEFAULT_HEIGHT + CHART_HEADER_HEIGHT
    end
  end

  def initialize(project: nil, query: nil)
    self.project = project
    self.query = query

    query.project = project if query && project
  end

  def color_schema
    AdditionalsPlugin.active_reporting? ? RedmineReporting.setting(:chart_color_schema) : 'tableau.Classic20'
  end

  def data
    raise 'overwrite it!'
  end

  # Data the additionals-chart Stimulus controller draws: type, labels,
  # datasets (label, data, optional urls per point), totalLabel (title of the
  # values) and colorSchema. The format is described in docs/charts.md.
  def payload
    raise 'overwrite it!'
  end

  def valid?
    raise 'overwrite it!'
  end

  def height
    CHART_DEFAULT_HEIGHT
  end

  def icon
    CHART_ICONS.fetch payload[:type], 'chart-bar'
  end

  # Calculates optimal height for bar charts based on number of elements
  # Provides different spacing strategies for different element counts
  #
  # @param elements [Integer] number of chart elements/bars
  # @param groups [Integer] number of data groups (default: 1)
  # @return [Integer] calculated height in pixels
  def calc_bar_height(elements, groups = 1)
    group_height = 20

    case elements
    when 0..2 then (group_height + 50) * groups
    when 3..4 then (elements * (group_height + 10) * groups)
    else (elements * group_height * groups)
    end
  end

  private

  # Periods of a timeline by unit (day, week, month, quarter, year), the
  # interval of the chart by default
  def period_start(date, unit = interval)
    case unit
    when 'day' then date
    when 'week' then date - ((date.cwday - first_wday) % 7)
    when 'quarter' then date.beginning_of_quarter
    when 'year' then date.beginning_of_year
    else date.beginning_of_month
    end
  end

  def period_end(start, unit = interval)
    case unit
    when 'day' then start
    when 'week' then start + 6
    when 'quarter' then start.end_of_quarter
    when 'year' then start.end_of_year
    else start.end_of_month
    end
  end

  # First day of a week as the calendar of core shows it, 1 = Monday ... 7 = Sunday
  def first_wday
    @first_wday ||= begin
      start_of_week = Setting.start_of_week.to_i
      start_of_week = l(:general_first_day_of_week).to_i unless [1, 6, 7].include? start_of_week
      ((start_of_week - 1) % 7) + 1
    end
  end

  # Weeks are numbered like in the calendar of core, by their Thursday
  def period_label(start, unit = interval)
    case unit
    when 'day' then format_date start
    when 'week'
      thursday = start + ((11 - start.cwday) % 7)
      l :label_chart_week, week: thursday.cweek, year: thursday.cwyear
    when 'quarter' then l(:label_chart_quarter, quarter: ((start.month - 1) / 3) + 1, year: start.year)
    when 'year' then start.year.to_s
    else
      l :label_chart_month, month: l('date.abbr_month_names')[start.month], year: start.year
    end
  end
end
