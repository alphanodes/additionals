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

  # Sums of hours look like the totals of the list, everything else like a number
  def format_query_chart_value(chart, value)
    chart.hours_measure? ? format_hours(value) : format_object(value)
  end

  # Data for the additionals-chart controller, values formatted like in the table of values
  def query_chart_payload(chart)
    texts = [chart.entries.map { |entry| format_query_chart_value chart, entry.value }]
    texts << chart.entries.map { |entry| format_query_chart_value chart, entry.compare_value } if chart.compare?

    chart.payload.merge totalText: format_query_chart_value(chart, chart.total), valueTexts: texts
  end
end
