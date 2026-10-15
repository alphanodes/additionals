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

  # A cell of the cross table, linked to the list filtered by both values
  def query_chart_part_cell(chart, entry, key)
    value = entry.parts[key]
    return '' if value.nil? || value.zero?

    text = format_query_chart_value chart, value
    url = entry.part_urls[key]
    url ? link_to(text, url) : text
  end
end
