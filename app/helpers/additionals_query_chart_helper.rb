# frozen_string_literal: true

module AdditionalsQueryChartHelper
  def options_for_query_chart_type(selected)
    options_for_select AdditionalsQueryChart::CHART_TYPES.map { |type| [l(:"label_chart_type_#{type}"), type] },
                       selected
  end

  def options_for_query_chart_order(selected)
    options_for_select AdditionalsQueryChart::ORDERS.map { |order| [l(:"label_chart_order_#{order}"), order] },
                       selected
  end

  def options_for_query_chart_interval(selected)
    labels = { 'week' => :label_week, 'month' => :label_month,
               'quarter' => :label_chart_interval_quarter, 'year' => :label_year }
    options_for_select AdditionalsQueryChart::INTERVALS.map { |interval| [l(labels[interval]), interval] },
                       selected
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

  # Sums of hours look like the totals of the list, everything else like a number
  def format_query_chart_value(chart, value)
    chart.hours_measure? ? format_hours(value) : format_object(value)
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

  # A cell of the cross table, linked to the list filtered by both values
  def query_chart_part_cell(chart, entry, key)
    value = entry.parts[key]
    return '' if value.nil? || value.zero?

    text = format_query_chart_value chart, value
    url = entry.part_urls[key]
    url ? link_to(text, url) : text
  end
end
