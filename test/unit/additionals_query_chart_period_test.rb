# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A block counts in a relative period of a date and compares it with the
# period before
class AdditionalsQueryChartPeriodTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    @issues = Issue.where(project: @project).order(:id).first 3
    Issue.update_all created_on: Time.utc(2020, 1, 1, 12)
    created_on @issues[0], 2026, 4, 2
    created_on @issues[1], 2026, 4, 8
    created_on @issues[2], 2026, 3, 20
  end

  def test_counts_the_entries_of_the_period
    in_april do
      assert_equal 2, period_chart(period: 'm').total
    end
  end

  # All entries of the query of the project, without its default filters. Not
  # Issue.visible: other plugins may treat a query of a project differently
  # (e.g. template projects, hidden from lists but not inside a project).
  def test_counts_all_entries_without_a_period
    in_april do
      assert_equal IssueQuery.new(project: @project, name: '_', filters: {}).issue_count, period_chart.total
    end
  end

  def test_compares_with_the_previous_period
    in_april do
      assert_equal 1, period_chart(period: 'm', compare_query_id: 'previous').compare_total
    end
  end

  def test_previous_of_last_month_is_the_month_before
    in_april do
      assert_equal 0, period_chart(period: 'lm', compare_query_id: 'previous').compare_total
    end
  end

  # 2026-04-15 is a Wednesday, the week of the German language starts on Monday
  def test_previous_week_starts_like_the_filters_of_core
    in_april do
      I18n.with_locale :de do
        chart = period_chart period: 'w', compare_query_id: 'previous'

        assert_equal ['><', %w[2026-04-06 2026-04-12]], url_filter(chart.entries.first.compare_url, 'created_on')
      end
    end
  end

  def test_url_of_an_entry_filters_by_the_period
    in_april do
      assert_equal ['m', ['']], url_filter(period_chart(period: 'm').entries.first.url, 'created_on')
    end
  end

  def test_url_of_the_previous_period_filters_by_its_days
    in_april do
      chart = period_chart period: 'm', compare_query_id: 'previous'

      assert_equal ['><', %w[2026-03-01 2026-03-31]], url_filter(chart.entries.first.compare_url, 'created_on')
    end
  end

  # Two date filters of the same field cannot be joined into one of the link
  def test_query_with_a_filter_of_the_date_has_no_url
    query = IssueQuery.create! name: 'Recent', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                               filters: { 'created_on' => { operator: '>t-', values: ['30'] } }

    in_april do
      assert_nil period_chart(period: 'm', query_id: query.id.to_s).entries.first.url
    end
  end

  def test_series_are_named_by_their_period
    in_april do
      I18n.with_locale :en do
        assert_equal ['Apr 2026', 'Mar 2026'], period_chart(period: 'm', compare_query_id: 'previous').series_labels
      end
    end
  end

  def test_title_names_the_date_and_the_period
    assert_includes period_chart(period: 'm').title, "#{::I18n.t :field_created_on}: #{::I18n.t :label_this_month}"
  end

  def test_previous_period_needs_a_period
    assert_not period_chart(compare_query_id: 'previous').compare?
  end

  def test_timeline_has_no_period
    assert_nil period_chart(group_by: 'start_date', period: 'm').period
  end

  def test_class_without_a_date_has_no_period
    chart = Additionals::TestIssueQueryChart.new project: @project, settings: { group_by: 'tracker', period: 'm' }

    assert_nil chart.period
  end

  # A fixed period: from a day up to today, or between two days
  def test_counts_the_entries_of_a_fixed_period
    in_april do
      assert_equal 1, period_chart(period: 'from', period_from: '2026-04-05').total
      assert_equal 2, period_chart(period: 'between', period_from: '2026-03-15', period_to: '2026-04-03').total
    end
  end

  # Without its days, or with the end before the start, a fixed period is none
  def test_fixed_period_without_its_days_counts_everything
    [{ period: 'from' }, { period: 'between', period_from: '2026-03-15' },
     { period: 'between', period_from: '2026-04-03', period_to: '2026-03-15' }].each do |settings|
      assert_nil period_chart(**settings).period, settings.inspect
    end
  end

  # The previous period has as many days, right before
  def test_compares_a_fixed_period_with_the_days_before
    in_april do
      chart = period_chart period: 'between', period_from: '2026-04-01', period_to: '2026-04-15', compare_query_id: 'previous'

      assert_equal 1, chart.compare_total
      assert_equal ['><', %w[2026-03-17 2026-03-31]], url_filter(chart.entries.first.compare_url, 'created_on')
    end
  end

  def test_url_of_an_entry_filters_by_the_fixed_period
    in_april do
      chart = period_chart period: 'from', period_from: '2026-04-01'

      assert_equal ['><', %w[2026-04-01 2026-04-15]], url_filter(chart.entries.first.url, 'created_on')
    end
  end

  def test_title_names_a_fixed_period
    chart = period_chart period: 'between', period_from: '2026-04-01', period_to: '2026-04-15'

    assert_includes chart.title, ::I18n.t(:label_date_from_to, start: format_date(Date.new(2026, 4, 1)),
                                                               end: format_date(Date.new(2026, 4, 15)))
  end

  # A distribution does not show its period, an own title hides it from the
  # one of the block; a timeline shows its days on the axis
  def test_note_tells_the_period_an_own_title_hides
    cases = { { title: 'Bugs' } => "#{::I18n.t :field_created_on}: #{::I18n.t :label_this_month}",
              {} => nil,
              { title: 'Bugs', group_by: 'created_on', period: 'from', period_from: '2026-04-01' } => nil }
    cases.each do |settings, note|
      in_april do
        assert_equal [note], [period_chart(period: 'm', **settings).period_note], settings.inspect
      end
    end
  end

  def test_unknown_period_counts_everything
    assert_nil period_chart(period: 'x').period
  end

  private

  def period_chart(**settings)
    settings = { group_by: 'tracker', chart_type: 'bar_horizontal' }.merge settings
    Additionals::TestPeriodIssueQueryChart.new project: @project, settings:
  end

  def in_april(&)
    travel_to Time.local(2026, 4, 15, 12), & # rubocop:disable Rails/TimeZone
  end

  def created_on(issue, year, month, day)
    Issue.where(id: issue.id).update_all created_on: Time.utc(year, month, day, 12)
  end

  def url_filter(url, field)
    params = Rack::Utils.parse_nested_query URI(url).query
    [params['op'][field], params['v'][field]]
  end
end
