# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Timelines of timestamps by the day of a user with a time zone of their own.
# The database counts per hour as stored, Ruby moves the hours to the days of
# the user: independent of the time zone tables of MySQL and the time zone of
# a PostgreSQL session. The timestamps are instants (UTC), so the expectations
# hold in any time zone of the server.
class AdditionalsQueryChartTimeZoneTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    @issues = Issue.where(project: @project).order(:id).first 4
    User.current.pref.update! time_zone: 'Berlin'
    @dated = []
  end

  def test_counts_the_day_of_the_user
    created_at @issues[0], Time.utc(2026, 1, 31, 23, 30)

    assert_equal Date.new(2026, 2, 1), chart.entries.first.key
  end

  def test_counts_the_day_of_a_user_west_of_the_server
    User.current.pref.update! time_zone: 'Pacific Time (US & Canada)'
    created_at @issues[0], Time.utc(2026, 2, 1, 6, 30)

    assert_equal Date.new(2026, 1, 1), chart.entries.first.key
  end

  # 22:30 UTC is midnight past in summer time (+2), not in winter time (+1)
  def test_counts_the_day_of_the_user_in_summer_time
    created_at @issues[0], Time.utc(2026, 7, 31, 22, 30)

    assert_equal Date.new(2026, 8, 1), chart.entries.first.key
  end

  def test_without_a_time_zone_of_the_user_counts_the_day_of_the_server
    User.current.pref.update! time_zone: ''
    time = Time.utc 2026, 1, 31, 23, 30
    created_at @issues[0], time

    assert_equal time.localtime.to_date.beginning_of_month, chart.entries.first.key
  end

  def test_adds_up_the_hours_of_a_day
    travel_to Time.utc(2026, 4, 15, 12) do
      created_at @issues[0], Time.utc(2026, 4, 2, 6)
      created_at @issues[1], Time.utc(2026, 4, 2, 20)
      created_at @issues[2], Time.utc(2026, 4, 2, 22, 30)

      assert_equal [2, 1], day_values(Date.new(2026, 4, 2), Date.new(2026, 4, 3))
    end
  end

  def test_leaves_out_entries_without_a_timestamp
    created_at @issues[0], Time.utc(2026, 1, 15, 12)
    Issue.where(id: @issues.map(&:id)).update_all closed_on: nil
    Issue.where(id: @issues[0].id).update_all closed_on: Time.utc(2026, 1, 31, 23, 30)

    assert_equal [[Date.new(2026, 2, 1), 1]], periods_with_values(chart(group_by: 'closed_on'))
  end

  def test_week_starts_on_the_day_of_the_user
    created_at @issues[0], Time.utc(2026, 3, 1, 23, 30)

    with_settings start_of_week: '1' do
      assert_equal Date.new(2026, 3, 2), chart(interval: 'week').entries.first.key
    end
  end

  def test_sums_up_a_totalable_column
    @issues.first(3).each { |issue| created_at issue, Time.utc(2026, 1, 15, 12) }
    Issue.where(id: @dated).update_all estimated_hours: 2

    assert_in_delta 6, chart(measure: 'estimated_hours').entries.first.value
  end

  def test_splits_the_periods
    @issues.first(3).each { |issue| created_at issue, Time.utc(2026, 1, 15, 12) }

    with_settings display_subprojects_issues: '0' do
      assert_equal 3, chart(split_by: 'tracker', chart_type: 'area').entries.first.parts.values.sum
    end
  end

  def test_compared_query_counts_the_day_of_the_user
    created_at @issues[0], Time.utc(2026, 1, 15, 12)
    created_at @issues[1], Time.utc(2026, 1, 31, 23, 30)
    compare = issues_query @issues[1]

    assert_equal [0, 1], chart(compare_query_id: compare.id.to_s).entries.first(2).map!(&:compare_value)
  end

  def test_latest_periods_count_like_the_whole_timeline
    created_at @issues[0], Time.utc(2026, 1, 15, 12)
    created_at @issues[1], Time.utc(2026, 2, 28, 23, 30)
    created_at @issues[2], Time.utc(2026, 3, 5, 12)

    travel_to Time.utc(2026, 3, 20, 12) do
      assert_equal timeline(chart).last(2), timeline(chart(max_entries: '2'))
    end
  end

  # 16:00 UTC is the next day in Tokyo, but still the day before in the time
  # of a server west of Tokyo: the first shown period begins at midnight of
  # the user
  def test_latest_periods_begin_at_midnight_of_the_user
    User.current.pref.update! time_zone: 'Tokyo'
    created_at @issues[0], Time.utc(2026, 1, 15, 12)
    created_at @issues[1], Time.utc(2026, 1, 31, 16)
    created_at @issues[2], Time.utc(2026, 3, 5, 12)

    travel_to Time.utc(2026, 3, 20, 12) do
      assert_equal [[Date.new(2026, 2, 1), 1], [Date.new(2026, 3, 1), 1]], timeline(chart(max_entries: '2'))
    end
  end

  # The link of a period filters the days of the user as core does
  def test_link_of_a_period_finds_its_entries
    created_at @issues[0], Time.utc(2026, 1, 31, 23, 30)
    entry = chart.entries.first

    assert_equal entry.value, linked_query(entry.url).issue_count
  end

  private

  def created_at(issue, time)
    Issue.where(id: issue.id).update_all created_on: time
    @dated << issue
  end

  # The issues a test dates only, so the creation of the fixtures does not count
  def chart(**settings)
    settings = { group_by: 'created_on', chart_type: 'line', query_id: issues_query(*@dated).id.to_s }.merge settings
    Additionals::TestIssueQueryChart.new project: @project, settings:
  end

  def issues_query(*issues)
    IssueQuery.create! name: 'Issues', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                       filters: { 'status_id' => { operator: '*', values: [''] },
                                  'issue_id' => { operator: '=', values: [issues.map(&:id).join(',')] } }
  end

  def timeline(chart)
    chart.entries.map { |entry| [entry.key, entry.value] }
  end

  def periods_with_values(chart)
    chart.entries.filter_map { |entry| [entry.key, entry.value] if entry.value.positive? }
  end

  def day_values(*days)
    values = chart(chart_type: 'calendar').entries.to_h { |entry| [entry.key, entry.value] }
    days.map { |day| values[day] }
  end

  def linked_query(url)
    query = IssueQuery.new name: '_', project: @project
    query.build_from_params Rack::Utils.parse_nested_query(URI(url).query).with_indifferent_access
    query
  end
end
