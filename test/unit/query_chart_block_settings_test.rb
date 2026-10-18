# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The settings of a query chart block, whose rules ask its chart class
class QueryChartBlockSettingsTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_date_field_is_a_timeline_with_an_interval
    assert applies?(:interval, group_by: 'created_on')
  end

  def test_category_has_no_interval
    assert_not applies?(:interval, group_by: 'tracker')
  end

  def test_timeline_has_no_period_order_or_empty_entries
    schema = schema_for({ group_by: 'created_on' }, with_period: true)

    assert_equal([false, false, false], %i[period order show_empty].map { |key| applies? key, schema })
  end

  def test_timeline_offers_series_types_and_calendar
    assert_equal AdditionalsQueryChart::TIMELINE_TYPES, offered(:chart_type, { group_by: 'created_on' })
  end

  def test_category_offers_no_timeline_only_types
    assert_equal AdditionalsQueryChart::CHART_TYPES - AdditionalsQueryChart::TIMELINE_ONLY_TYPES,
                 offered(:chart_type, { group_by: 'tracker' })
  end

  def test_calendar_has_neither_interval_nor_table
    schema = schema_for({ group_by: 'created_on', chart_type: 'calendar' })

    assert_equal([false, false], %i[interval with_table].map { |key| applies? key, schema })
  end

  def test_doughnut_shows_no_series
    schema = schema_for({ group_by: 'tracker', chart_type: 'doughnut' })

    assert_equal([false, false], %i[split_by compare_query_id].map { |key| applies? key, schema })
  end

  def test_bars_show_series
    schema = schema_for({ group_by: 'tracker', chart_type: 'bar_vertical' })

    assert_equal([true, true], %i[split_by compare_query_id].map { |key| applies? key, schema })
  end

  def test_previous_period_is_offered_with_a_period
    assert_includes offered(:compare_query_id, { group_by: 'tracker', period: 'm' }, with_period: true),
                    AdditionalsQueryChart::PREVIOUS_PERIOD
  end

  def test_previous_period_is_not_offered_without_a_period
    assert_not_includes offered(:compare_query_id, { group_by: 'tracker' }, with_period: true), AdditionalsQueryChart::PREVIOUS_PERIOD
  end

  def test_previous_period_is_no_value_without_a_period_field
    assert_includes schema_for({ group_by: 'tracker', compare_query_id: AdditionalsQueryChart::PREVIOUS_PERIOD }).errors,
                    :compare_query_id
  end

  def test_period_exists_with_a_period_field_only
    assert_not_includes keys(schema_for({ group_by: 'tracker' })), :period
  end

  def test_period_is_named_by_its_date
    period = describe(schema_for({ group_by: 'tracker' }, with_period: true)).detect { |setting| setting[:key] == :period }

    assert_includes period[:label], Additionals::TestPeriodIssueQueryChart.new(project: @project).period_caption
  end

  def test_open_only_exists_if_the_chart_supports_it
    assert_includes keys(schema_for({ group_by: 'status' }, chart_class: 'Additionals::TestProjectQueryChart')), :open_only
  end

  def test_open_only_does_not_exist_without_support
    assert_not_includes keys(schema_for({ group_by: 'tracker' })), :open_only
  end

  def test_group_by_is_required
    assert_includes schema_for({}).errors, :group_by
  end

  def test_split_by_offers_no_group_field
    assert_not_includes offered(:split_by, { group_by: 'tracker' }), 'tracker'
  end

  def test_split_by_offers_another_field
    assert_includes offered(:split_by, { group_by: 'tracker' }), 'status'
  end

  def test_split_by_offers_no_date
    assert_not_includes offered(:split_by, { group_by: 'tracker' }), 'created_on'
  end

  def test_classes_apply_to_a_number_field
    assert applies?(:classes, group_by: 'estimated_hours')
  end

  def test_classes_do_not_apply_to_a_category
    assert_not applies?(:classes, group_by: 'tracker')
  end

  def test_chart_type_of_a_timeline_defaults_to_line
    assert_equal 'line', schema_for({ group_by: 'created_on' })[:chart_type]
  end

  def test_chart_type_of_a_category_defaults_to_doughnut
    assert_equal 'doughnut', schema_for({ group_by: 'tracker' })[:chart_type]
  end

  def test_empty_entries_and_table_default_to_on
    schema = schema_for({ group_by: 'tracker' })

    assert_equal [true, true], [schema[:show_empty], schema[:with_table]]
  end

  def test_measure_defaults_to_the_chart
    assert_equal AdditionalsQueryChart::MEASURE_COUNT, schema_for({ group_by: 'tracker' })[:measure]
  end

  def test_title_defaults_to_the_chart
    assert_equal Additionals::TestIssueQueryChart.new(project: @project, settings: { group_by: 'tracker' }).title,
                 schema_for({ group_by: 'tracker' })[:title]
  end

  def test_queries_are_those_of_the_project
    values = describe(schema_for({ group_by: 'tracker' })).detect { |setting| setting[:key] == :query_id }[:values]

    assert_equal DashboardContent.selectable_queries(IssueQuery, @project).map { |query| query.id.to_s }, values.pluck(:value)
  end

  def test_unknown_group_field_is_invalid
    assert_includes schema_for({ group_by: 'no_such_column' }).errors, :group_by
  end

  # The settings form hides what does not apply in the browser with the values
  # of the chart (additionals_chart_settings_controller.js), the server decides
  # the same for every field of the groups
  def test_settings_form_and_server_agree_on_timelines
    chart = Additionals::TestIssueQueryChart.new project: @project
    timelines = chart.group_options.map(&:last).select { |name| applies? :interval, group_by: name }

    assert_equal chart.timeline_group_names.sort, timelines.sort
  end

  def test_settings_form_and_server_agree_on_classes
    chart = Additionals::TestIssueQueryChart.new project: @project
    classes = chart.group_options.map(&:last).select { |name| applies? :classes, group_by: name }

    assert_equal chart.number_group_names.sort, classes.sort
  end

  def test_settings_form_and_server_agree_on_series_types
    %w[tracker created_on].each do |group_by|
      types = offered :chart_type, { group_by: }
      series = types.select { |type| applies? :split_by, { group_by:, chart_type: type } }

      assert_equal types & AdditionalsQueryChart::SERIES_TYPES, series, group_by
    end
  end

  private

  def block_class(chart_name)
    Class.new(DashboardBlocks::QueryChartBlock) { chart chart_name }
  end

  # Values of the settings, chart_class: or with_period: choose the chart
  def schema_for(values = {}, chart_class: nil, with_period: false)
    chart_class ||= with_period ? 'Additionals::TestPeriodIssueQueryChart' : 'Additionals::TestIssueQueryChart'
    block = block_class(chart_class).new DashboardContentProject.new(project: @project)
    Additionals::SettingsSchema.new block.declared_settings, values, user: User.current, project: @project
  end

  def applies?(key, values)
    schema = values.is_a?(Additionals::SettingsSchema) ? values : schema_for(values)
    describe(schema).detect { |setting| setting[:key] == key }[:applies]
  end

  def offered(key, values, with_period: false)
    describe(schema_for(values, with_period:)).detect { |setting| setting[:key] == key }[:offered]
  end

  def describe(schema)
    schema.describe
  end

  def keys(schema)
    describe(schema).pluck :key
  end
end
