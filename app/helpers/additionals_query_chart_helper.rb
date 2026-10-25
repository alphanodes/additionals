# frozen_string_literal: true

module AdditionalsQueryChartHelper
  # Not in any text of a summary
  SUMMARY_VALUE_MARK = "\u0000"

  def options_for_query_chart_type(selected)
    options_for_select AdditionalsQueryChart::CHART_TYPES.map { |type| [l(:"label_chart_type_#{type}"), type] },
                       selected
  end

  # The settings form with its rules (additionals_chart_settings_controller.js)
  # from the chart class, as the server decides with the block settings, and
  # the url of its summary for the values of the open form
  def query_chart_settings_box(chart, summary_url:, &)
    values = { 'timeline-groups' => chart.timeline_group_names.to_json,
               'number-groups' => chart.number_group_names.to_json,
               'default-classes' => chart.default_classes.to_json,
               'automatic-classes' => l(:label_chart_classes_auto),
               'timeline-types' => AdditionalsQueryChart::TIMELINE_TYPES.to_json,
               'timeline-only-types' => AdditionalsQueryChart::TIMELINE_ONLY_TYPES.to_json,
               'series-types' => AdditionalsQueryChart::SERIES_TYPES.to_json,
               'previous-period' => AdditionalsQueryChart::PREVIOUS_PERIOD,
               'no-timeline-reason' => l(:label_chart_type_no_timeline),
               'timeline-only-reason' => l(:label_chart_type_timeline_only),
               'summary-url' => summary_url }
    data = values.transform_keys { |key| "additionals-chart-settings-#{key}-value" }
    tag.div class: 'box tabular settings query-chart-settings',
            data: { controller: 'additionals-chart-settings',
                    action: 'change->additionals-chart-settings#refreshSummary', **data }, &
  end

  # What empty bounds mean for the chosen field: its own bounds or automatic ones
  def query_chart_classes_placeholder(chart)
    chart.default_classes[chart.group_column&.name.to_s] || l(:label_chart_classes_auto)
  end

  # The summary of the chart with its values set off, so the reader sees
  # at a glance what the settings choose. Marks stand in for the values
  # while the sentence is put together, the rest of it is escaped.
  def query_chart_summary(chart)
    values = []
    text = chart.summary do |value|
      values << value.to_s.delete(SUMMARY_VALUE_MARK)
      "#{SUMMARY_VALUE_MARK}#{values.size - 1}#{SUMMARY_VALUE_MARK}"
    end
    parts = text.split(SUMMARY_VALUE_MARK).each_with_index.map do |part, index|
      index.odd? ? tag.span(values[part.to_i], class: 'query-chart-summary-value') : part
    end
    safe_join parts
  end

  # As in the title of the block; bars of the horizontal type lie on their side
  def query_chart_type_icon(type)
    svg_icon_tag AdditionalsChart.type_icon(type), css_class: ('query-chart-icon-horizontal' if type == 'bar_horizontal')
  end

  def options_for_query_chart_order(selected)
    options_for_select AdditionalsQueryChart::ORDERS.map { |order| [l(:"label_chart_order_#{order}"), order] },
                       selected
  end

  def options_for_query_chart_interval(selected)
    intervals = AdditionalsQueryChart::INTERVALS.map { |interval| [l(AdditionalsQueryChart::INTERVAL_LABELS[interval]), interval] }
    options_for_select intervals, selected
  end

  def options_for_query_chart_period(selected)
    periods = AdditionalsQueryChart::PERIOD_LABELS.map { |code, label| [l(label), code] }
    options_for_select [[l(:label_all), '']] + periods, selected
  end

  # The queries of the chart class, and the previous period where the block
  # counts in a period
  def options_for_query_chart_compare(chart, project, selected)
    previous = if chart.period_supported?
                 tag.option l(:label_chart_previous_period), value: AdditionalsQueryChart::PREVIOUS_PERIOD,
                                                             selected: selected == AdditionalsQueryChart::PREVIOUS_PERIOD
               end
    options_for_query_select chart.query_class, project, selected, leading: previous
  end

  # A chart may format its values itself (e.g. amounts with their currency),
  # otherwise sums of hours look like the totals of the list, everything else
  # like a number
  def format_query_chart_value(chart, value)
    chart.value_text(value) || (chart.hours_measure? ? format_hours(value) : format_object(value))
  end

  # Data for the additionals-chart controller, values formatted like in the table of values
  def query_chart_payload(chart)
    payload = chart.payload
    texts = payload[:datasets].map do |dataset|
      dataset[:data].map { |value| format_query_chart_value chart, value }
    end

    payload.merge totalText: format_query_chart_value(chart, chart.total), valueTexts: texts
  end

  # The descriptions of the saved queries a chart counts, each with the link
  # to its list
  def query_chart_query_descriptions(chart)
    safe_join(chart.described_queries.map do |query|
      tag.div class: 'query-chart-query-description' do
        safe_join [tag.div(safe_join([l(:label_query), ': ', link_to(query.name, chart.query_url(query))])),
                   tag.div(textilizable(query, :description), class: 'wiki')]
      end
    end)
  end

  # A value of the table of values, a part of a split linked to the list
  # filtered by both values
  def query_chart_cell(chart, cell)
    return '' if cell.part && cell.value.zero?

    text = format_query_chart_value chart, cell.value
    cell.url ? link_to(text, cell.url) : text
  end
end
