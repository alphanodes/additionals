# frozen_string_literal: true

module DashboardBlocks
  # A chart of a saved query (AdditionalsQueryChart). The block holds its
  # chart: chart classes are used outside of dashboards as well and know
  # nothing about them.
  #
  # The rules of the settings ask a chart built with the values at hand
  # instead of restating it, so a chart class of another plugin overriding
  # e.g. period_field or default_measure is covered.
  class QueryChartBlock < Base
    abstract!

    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS

    settings_partial 'dashboards/blocks/query_chart_settings'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :description, type: :text, label: :field_description
    setting :query_id, type: :enum, label: :label_query
    setting :open_only, type: :boolean
    setting :group_by, type: :enum, label: :field_group_by, required: true
    setting :interval, type: :enum, label: :label_chart_interval
    setting :classes, type: :string, label: :label_chart_classes
    setting :period, type: :enum
    setting :split_by, type: :enum, label: :label_chart_split_by
    setting :measure, type: :enum, label: :label_chart_measure
    setting :chart_type, type: :enum, label: :label_display_type
    setting :compare_query_id, type: :enum, label: :label_chart_compare_query
    setting :order, type: :enum, label: :label_sort
    setting :max_entries, type: :integer, label: :label_max_entries, min: 0
    setting :min_share, type: :float, label: :label_chart_min_share, min: 0, max: 100
    setting :show_empty, type: :boolean, label: :label_chart_show_empty, default: true
    setting :with_table, type: :boolean, label: :label_table_of_values, default: true

    class_attribute :chart_class, instance_writer: false

    class << self
      # The chart class, named as a string (see Base)
      def chart(name = nil)
        name ? self.chart_class = name.to_s : chart_class&.constantize
      end

      def async(**options)
        return super if options.any?

        async_options || { required_settings: %i[group_by],
                           partial: 'dashboards/blocks/query_chart',
                           libraries: %i[chartjs_meta query_chart],
                           lazy: true,
                           data_check_class: chart }
      end
    end

    # The chart of the stored settings, which falls back itself where a value
    # does not fit (charts are used outside of dashboards as well)
    def chart
      @chart ||= self.class.chart.new project:, settings: @stored_settings
    end

    def data
      chart
    end

    # The table of values of the chart (AdditionalsQueryChart#value_columns),
    # a timeline from its first period on with the start date of each period
    # instead of its label
    def export_data
      return unless chart.group_column

      export = { summary: chart.summary }
      return export.merge unavailable: chart.unavailable_text if chart.unavailable_text

      export[:interval] = chart.interval if chart.timeline?
      export.merge columns: [chart.group_column.caption, *chart.value_columns],
                   rows: chart.entries.map { |entry| export_row entry },
                   totals: chart.value_totals.map { |value| export_number value }
    end

    private

    def export_row(entry)
      [export_value(chart.timeline? ? entry.key : entry.label), *chart.entry_cells(entry).map { |cell| export_number cell.value }]
    end

    # The chart of the values a schema reads, built once per schema
    def chart_for(schema)
      return chart if schema.equal? @settings_schema

      @charts ||= {}.compare_by_identity
      @charts[schema] ||= self.class.chart.new project:, settings: schema.values
    end

    def title_default(schema)
      chart_for(schema).title
    end

    def query_id_values(schema)
      queries_of chart_for(schema)
    end

    def open_only_available?(schema)
      chart_for(schema).open_only_supported?
    end

    def open_only_label(schema)
      chart_for(schema).open_only_label
    end

    def group_by_values(schema)
      chart_for(schema).group_options
    end

    def interval_values(_schema)
      labels = { 'week' => :label_week, 'month' => :label_month, 'quarter' => :label_chart_interval_quarter, 'year' => :label_year }
      AdditionalsQueryChart::INTERVALS.map { |interval| [I18n.t(labels[interval]), interval] }
    end

    def interval_default(_schema)
      AdditionalsQueryChart::DEFAULT_INTERVAL
    end

    # A calendar shows days
    def interval_applies?(schema)
      chart = chart_for schema
      chart.timeline? && !chart.calendar?
    end

    def classes_applies?(schema)
      chart_for(schema).number_classes?
    end

    def period_available?(schema)
      chart_for(schema).period_supported?
    end

    def period_values(_schema)
      AdditionalsQueryChart::PERIOD_LABELS.map { |code, label| [I18n.t(label), code] }
    end

    # A timeline shows its periods itself
    def period_applies?(schema)
      !chart_for(schema).timeline?
    end

    def period_label(schema)
      "#{I18n.t :label_chart_period} (#{chart_for(schema).period_caption})"
    end

    def split_by_values(schema)
      chart_for(schema).split_options
    end

    # Never the field of the groups, and at most one of both with multiple
    # values: the chart could not join the values of two of them
    def split_by_offered(schema)
      chart_for(schema).offered_split_names
    end

    def split_by_applies?(schema)
      series_type? schema
    end

    def measure_values(schema)
      chart_for(schema).measure_options
    end

    def measure_default(schema)
      chart_for(schema).default_measure
    end

    def chart_type_values(_schema)
      AdditionalsQueryChart::CHART_TYPES.map { |type| [I18n.t(:"label_chart_type_#{type}"), type] }
    end

    # Line, area and calendar are timelines only, a timeline is no doughnut,
    # pie or treemap
    def chart_type_offered(schema)
      if chart_for(schema).timeline?
        AdditionalsQueryChart::TIMELINE_TYPES
      else
        AdditionalsQueryChart::CHART_TYPES - AdditionalsQueryChart::TIMELINE_ONLY_TYPES
      end
    end

    def chart_type_default(schema)
      chart_for(schema).timeline? ? AdditionalsQueryChart::LINE_TYPES.first : AdditionalsQueryChart::CHART_TYPES.first
    end

    def compare_query_id_values(schema)
      chart = chart_for schema
      previous = chart.period_supported? ? [[I18n.t(:label_chart_previous_period), AdditionalsQueryChart::PREVIOUS_PERIOD]] : []
      previous + queries_of(chart)
    end

    # The previous period compares a block counting in a period
    def compare_query_id_offered(schema)
      values = compare_query_id_values(schema).map(&:last)
      return values if schema[:period].present? && period_applies?(schema)

      values - [AdditionalsQueryChart::PREVIOUS_PERIOD]
    end

    def compare_query_id_applies?(schema)
      series_type? schema
    end

    # Periods and classes keep the order of their values
    def order_applies?(schema)
      chart = chart_for schema
      !chart.timeline? && !chart.number_classes?
    end

    def order_default(_schema)
      AdditionalsQueryChart::ORDERS.first
    end

    def order_values(_schema)
      AdditionalsQueryChart::ORDERS.map { |order| [I18n.t(:"label_chart_order_#{order}"), order] }
    end

    def max_entries_applies?(schema)
      !chart_for(schema).number_classes?
    end

    def show_empty_applies?(schema)
      !chart_for(schema).timeline?
    end

    def with_table_applies?(schema)
      !chart_for(schema).calendar?
    end

    # Doughnut, pie and treemap show no series
    def series_type?(schema)
      AdditionalsQueryChart::SERIES_TYPES.include? chart_for(schema).chart_type
    end

    def queries_of(chart)
      DashboardContent.selectable_queries(chart.query_class, project).map { |query| [query.name, query.id.to_s] }
    end
  end
end
