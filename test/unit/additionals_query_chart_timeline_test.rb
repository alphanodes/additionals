# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A date column groups by periods: a timeline of weeks, months, quarters or years
class AdditionalsQueryChartTimelineTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    @issues = Issue.where(project: @project).order(:id).first 3
    Issue.update_all start_date: nil
    set_start_dates '2026-01-15', '2026-01-20', '2026-03-05'
  end

  def test_group_options_contain_a_date
    assert_includes group_names(timeline_chart), 'start_date'
  end

  def test_group_options_contain_a_timestamp
    assert_includes group_names(timeline_chart), 'created_on'
  end

  def test_group_options_contain_a_date_field
    field = date_field

    assert_includes group_names(timeline_chart), "cf_#{field.id}"
  end

  def test_split_options_do_not_contain_a_date
    assert_not_includes timeline_chart.split_options.map(&:last), 'start_date'
  end

  def test_timeline_groups_contain_a_date
    assert_includes timeline_chart.timeline_group_names, 'start_date'
  end

  def test_timeline_groups_do_not_contain_a_category
    assert_not_includes timeline_chart.timeline_group_names, 'tracker'
  end

  def test_a_date_is_a_timeline
    assert_predicate timeline_chart, :timeline?
  end

  def test_a_category_is_no_timeline
    assert_not timeline_chart(group_by: 'tracker').timeline?
  end

  def test_interval_defaults_to_month
    assert_equal 'month', timeline_chart(interval: 'unknown').interval
  end

  def test_sums_up_the_entries_per_month
    with_settings display_subprojects_issues: '0' do
      assert_equal [2, 0, 1], timeline_chart.entries.map(&:value)
    end
  end

  def test_periods_without_entries_fill_the_gaps
    assert_equal [Date.new(2026, 1, 1), Date.new(2026, 2, 1), Date.new(2026, 3, 1)], timeline_chart.entries.map(&:key)
  end

  # The latest period is of most interest in the table, the chart reads
  # from left to right
  def test_table_shows_the_latest_period_first
    assert_equal [Date.new(2026, 3, 1), Date.new(2026, 2, 1), Date.new(2026, 1, 1)], timeline_chart.table_entries.map(&:key)
  end

  def test_table_of_a_category_keeps_the_order_of_the_chart
    chart = timeline_chart group_by: 'tracker'

    assert_equal chart.entries, chart.table_entries
  end

  def test_sums_up_the_entries_per_quarter
    with_settings display_subprojects_issues: '0' do
      assert_equal({ Date.new(2026, 1, 1) => 3 }, entry_values(timeline_chart(interval: 'quarter')))
    end
  end

  def test_sums_up_the_entries_per_year
    set_start_dates '2025-12-31'

    assert_equal [Date.new(2025, 1, 1), Date.new(2026, 1, 1)], timeline_chart(interval: 'year').entries.map(&:key)
  end

  # 2026-01-15 is a Thursday

  def test_weeks_start_on_monday
    with_settings start_of_week: '1' do
      assert_equal Date.new(2026, 1, 12), timeline_chart(interval: 'week').entries.first.key
    end
  end

  def test_weeks_start_on_the_start_of_week
    with_settings start_of_week: '7' do
      assert_equal Date.new(2026, 1, 11), timeline_chart(interval: 'week').entries.first.key
    end
  end

  def test_entries_without_a_date_are_left_out
    assert_not_includes timeline_chart(show_empty: '1').entries.map(&:key), nil
  end

  def test_periods_are_in_the_order_of_time
    assert_equal [Date.new(2026, 1, 1), Date.new(2026, 2, 1), Date.new(2026, 3, 1)],
                 timeline_chart(order: 'value').entries.map(&:key)
  end

  def test_max_entries_shows_the_latest_periods
    assert_equal [Date.new(2026, 2, 1), Date.new(2026, 3, 1)], timeline_chart(max_entries: '2').entries.map(&:key)
  end

  # The query counts from the first shown period on only
  def test_latest_periods_count_like_the_whole_timeline
    assert_equal timeline_values(timeline_chart).last(2), timeline_values(timeline_chart(max_entries: '2'))
  end

  def test_latest_periods_of_a_timestamp_count_like_the_whole_timeline
    Issue.where(id: @issues.map(&:id)).update_all created_on: Time.utc(2026, 1, 15, 12)
    Issue.where(id: @issues.last.id).update_all created_on: Time.utc(2026, 3, 5, 12)
    query_id = IssueQuery.create!(name: 'Mine', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                  filters: { 'issue_id' => { operator: '=', values: [@issues.map(&:id).join(',')] } }).id.to_s

    travel_to Time.local(2026, 3, 20, 12) do # rubocop:disable Rails/TimeZone
      assert_equal timeline_values(timeline_chart(group_by: 'created_on', query_id:)).last(2),
                   timeline_values(timeline_chart(group_by: 'created_on', query_id:, max_entries: '2'))
    end
  end

  # The compared query ends earlier, its periods within the shown ones still count
  def test_latest_periods_keep_the_values_of_the_compared_query
    compare = IssueQuery.create! name: 'January', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                 filters: { 'start_date' => { operator: '<=', values: ['2026-01-31'] } }
    chart = timeline_chart compare_query_id: compare.id.to_s, max_entries: '3'

    assert_equal [2, 0, 0], chart.entries.map(&:compare_value)
  end

  def test_min_share_does_not_combine_periods
    assert_not_includes timeline_chart(min_share: '50').entries.map(&:key), AdditionalsQueryChart::OTHERS
  end

  def test_label_of_a_month
    I18n.with_locale :en do
      assert_equal 'Jan 2026', timeline_chart.entries.first.label
    end
  end

  def test_label_of_a_week
    I18n.with_locale :en do
      with_settings start_of_week: '1' do
        assert_equal 'W3/2026', timeline_chart(interval: 'week').entries.first.label
      end
    end
  end

  def test_label_of_a_quarter
    I18n.with_locale :en do
      assert_equal 'Q1 2026', timeline_chart(interval: 'quarter').entries.first.label
    end
  end

  def test_label_of_a_year
    assert_equal '2026', timeline_chart(interval: 'year').entries.first.label
  end

  def test_url_of_a_period_filters_its_days
    url = timeline_chart.entries.first.url

    assert_equal ['><', %w[2026-01-01 2026-01-31]], url_filter(url, 'start_date')
  end

  # The filter of the query on the same date keeps its bounds, the link of a
  # period replaces it

  def test_url_of_a_period_keeps_the_bounds_of_the_query_filter
    query = IssueQuery.create! name: 'Started', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                               filters: { 'start_date' => { operator: '>=', values: ['2026-01-18'] } }
    url = timeline_chart(query_id: query.id.to_s).entries.first.url

    assert_equal ['><', %w[2026-01-20 2026-01-31]], url_filter(url, 'start_date')
  end

  # Weeks without entries since the last one are what a timeline of the past shows
  def test_timeline_of_past_dates_ends_today
    Issue.where(id: @issues.first.id).update_all created_on: Time.utc(2026, 1, 15, 12)

    travel_to Time.local(2026, 4, 15, 12) do # rubocop:disable Rails/TimeZone
      chart = timeline_chart group_by: 'created_on', query_id: created_query.id.to_s

      assert_equal Date.new(2026, 4, 1), chart.entries.last.key
    end
  end

  # Start dates may lie in the future, the last one ends the timeline
  def test_timeline_of_other_dates_ends_with_the_last_entry
    travel_to Time.local(2026, 10, 15, 12) do # rubocop:disable Rails/TimeZone
      assert_equal Date.new(2026, 3, 1), timeline_chart.entries.last.key
    end
  end

  def test_groups_by_a_date_field
    field = date_field
    CustomValue.create! custom_field: field, customized: @issues.first, value: '2026-05-04'

    assert_equal({ Date.new(2026, 5, 1) => 1 }, entry_values(timeline_chart(group_by: "cf_#{field.id}")))
  end

  def test_sums_up_a_totalable_column_per_period
    Issue.where(id: @issues.map(&:id)).update_all estimated_hours: 2

    assert_in_delta 4, timeline_chart(measure: 'estimated_hours').entries.first.value
  end

  def test_splits_the_periods
    with_settings display_subprojects_issues: '0' do
      chart = timeline_chart split_by: 'tracker', chart_type: 'area'

      assert_equal 2, chart.entries.first.parts.values.sum
    end
  end

  def test_url_of_a_part_filters_by_the_period
    assert_equal ['><', %w[2026-01-01 2026-01-31]], url_filter(first_part_url, 'start_date')
  end

  def test_url_of_a_part_filters_by_the_split
    assert_equal ['=', [@issues.first.tracker_id.to_s]], url_filter(first_part_url, 'tracker_id')
  end

  def test_splits_the_periods_of_a_timestamp
    Issue.where(id: @issues.first.id).update_all created_on: Time.utc(2026, 1, 15, 12)
    chart = timeline_chart group_by: 'created_on', split_by: 'tracker', chart_type: 'area',
                           query_id: created_query.id.to_s

    assert_equal({ @issues.first.tracker => 1 }, chart.entries.first.parts)
  end

  def test_splits_the_periods_by_a_field_with_multiple_values
    field = IssueCustomField.create! name: 'Platforms', field_format: 'list', possible_values: %w[A B],
                                     multiple: true, is_for_all: true, is_filter: true, tracker_ids: Tracker.ids
    %w[A B].each { |value| CustomValue.create! custom_field: field, customized: @issues.first, value: }
    chart = timeline_chart split_by: "cf_#{field.id}", chart_type: 'area', show_empty: '0'

    assert_equal({ 'A' => 1, 'B' => 1 }, chart.entries.first.parts)
  end

  # January only has entries of the compared query, the own query filters it out
  def test_period_outside_of_the_filter_of_the_query_has_no_url
    query = IssueQuery.create! name: 'March', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                               filters: { 'start_date' => { operator: '>=', values: ['2026-03-01'] } }
    compare = IssueQuery.create! name: 'All', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC
    chart = timeline_chart query_id: query.id.to_s, compare_query_id: compare.id.to_s

    assert_nil chart.entries.first.url
  end

  def test_week_at_the_end_of_a_year
    set_start_dates '2026-12-31'

    I18n.with_locale :en do
      with_settings start_of_week: '1' do
        assert_equal 'W53/2026', timeline_chart(interval: 'week', max_entries: '1').entries.last.label
      end
    end
  end

  # A year mistyped as 0202 would fill the timeline with empty years
  def test_timeline_has_at_most_max_periods
    set_start_dates '0202-01-01'

    assert_equal AdditionalsQueryChart::MAX_PERIODS, timeline_chart(interval: 'year').entries.size
  end

  def test_timeline_without_dates_is_not_valid
    Issue.update_all start_date: nil

    assert_not timeline_chart.valid?
  end

  def test_line_is_the_default_display_of_a_timeline
    assert_equal 'line', timeline_chart(chart_type: 'doughnut').chart_type
  end

  def test_timeline_can_be_shown_as_bars
    assert_equal 'bar_vertical', timeline_chart(chart_type: 'bar_vertical').chart_type
  end

  def test_line_falls_back_to_bars_for_a_category
    assert_equal 'bar_vertical', timeline_chart(group_by: 'tracker', chart_type: 'line').chart_type
  end

  def test_split_area_is_stacked
    assert timeline_chart(split_by: 'tracker', chart_type: 'area').payload[:stacked]
  end

  def test_split_lines_are_not_stacked
    assert_not timeline_chart(split_by: 'tracker', chart_type: 'line').payload[:stacked]
  end

  def test_line_shows_a_comparison
    query = IssueQuery.create! name: 'Compare', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC

    assert_predicate timeline_chart(compare_query_id: query.id.to_s), :compare?
  end

  private

  def timeline_chart(**settings)
    settings = { group_by: 'start_date', chart_type: 'line' }.merge settings
    Additionals::TestIssueQueryChart.new project: @project, settings:
  end

  def first_part_url
    timeline_chart(split_by: 'tracker', chart_type: 'area').entries.first.part_urls[@issues.first.tracker]
  end

  def set_start_dates(*dates)
    dates.each_with_index { |date, index| Issue.where(id: @issues[index].id).update_all start_date: date }
  end

  # Only the issues with a start date, so the creation of the fixtures does not count
  def created_query
    IssueQuery.create! name: 'Created', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                       filters: { 'issue_id' => { operator: '=', values: [@issues.first.id.to_s] } }
  end

  def date_field
    IssueCustomField.create! name: 'Delivery', field_format: 'date', is_for_all: true, is_filter: true,
                             tracker_ids: Tracker.ids
  end

  def group_names(chart)
    chart.group_options.map(&:last)
  end

  def timeline_values(chart)
    chart.entries.map { |entry| [entry.key, entry.value] }
  end

  def entry_values(chart)
    chart.entries.to_h { |entry| [entry.key, entry.value] }
  end

  def url_filter(url, field)
    params = Rack::Utils.parse_nested_query URI(url).query
    [params['op'][field], params['v'][field]]
  end
end
