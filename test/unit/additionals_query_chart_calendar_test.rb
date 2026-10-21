# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A timeline by day as calendar: the days of a year in columns of weeks, the
# colors in levels of the values
class AdditionalsQueryChartCalendarTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    @issues = Issue.where(project: @project).order(:id).first 4
    Issue.update_all created_on: Time.utc(2020, 1, 1, 12)
    created_on @issues[0], 2026, 4, 2
    created_on @issues[1], 2026, 4, 2
    created_on @issues[2], 2026, 4, 8
    created_on @issues[3], 2026, 3, 20
  end

  def test_calendar_is_offered_for_a_date
    assert_equal 'calendar', calendar_chart.chart_type
  end

  def test_calendar_falls_back_to_bars_for_a_category
    assert_equal 'bar_vertical', calendar_chart(group_by: 'tracker').chart_type
  end

  def test_calendar_shows_days
    assert_equal 'day', calendar_chart(interval: 'month').interval
  end

  def test_calendar_counts_the_entries_of_a_day
    in_april do
      assert_equal 2, calendar_chart.entries.detect { |entry| entry.key == Date.new(2026, 4, 2) }.value
    end
  end

  def test_calendar_ends_today
    in_april do
      assert_equal Date.new(2026, 4, 15), calendar_chart.entries.last.key
    end
  end

  # 53 weeks from the first day of a week on, Monday with the default settings
  def test_calendar_starts_with_the_first_day_of_a_week
    in_april do
      with_settings start_of_week: '1' do
        assert_equal 1, calendar_chart.entries.first.key.cwday
      end
    end
  end

  def test_calendar_has_a_column_per_week
    in_april do
      assert_equal AdditionalsQueryChart::CALENDAR_WEEKS, calendar_chart.payload[:calendar][:weeks]
    end
  end

  def test_first_row_is_the_first_day_of_a_week
    in_april do
      with_settings start_of_week: '7' do
        I18n.with_locale :en do
          assert_equal 'Sun', calendar_chart.payload[:calendar][:weekdays].first
        end
      end
    end
  end

  # Even if the next month starts soon: the chart leaves out what does not fit
  def test_first_column_names_its_month
    in_april do
      with_settings start_of_week: '1' do
        I18n.with_locale :en do
          assert_equal 'Apr', calendar_chart.payload[:calendar][:months][0]
        end
      end
    end
  end

  def test_first_day_is_the_first_cell
    in_april do
      assert_equal({ x: 0, y: 0 }, calendar_chart.payload[:calendar][:points].first.slice(:x, :y))
    end
  end

  # Days without values do not count for the levels, equal bounds are one
  def test_levels_are_quantiles_of_the_days_with_values
    in_april do
      assert_equal [1], calendar_chart.payload[:calendar][:levels]
    end
  end

  def test_levels_split_the_days_into_quarters
    Issue.where.not(id: @issues.map(&:id)).order(:id).limit(6).each_with_index do |issue, index|
      created_on issue, 2026, 4, 9 + (index % 3)
    end
    chart = Additionals::TestIssueQueryChart.new project: nil, settings: { group_by: 'created_on', chart_type: 'calendar' }

    in_april do
      # Days with 1, 1, 2, 2, 2, 2 entries
      assert_equal [1, 2], chart.payload[:calendar][:levels]
    end
  end

  def test_legend_names_the_values_of_the_levels
    in_april do
      I18n.with_locale :en do
        assert_equal ['0', 'up to 1', 'above 1'], calendar_chart.payload[:calendar][:legend]
      end
    end
  end

  # The settings form keeps the choice for another display type
  def test_calendar_shows_no_table_of_values_but_keeps_the_choice
    chart = calendar_chart with_table: '1'

    assert_equal [false, true], [chart.with_table?, chart.table_chosen?]
  end

  def test_url_of_a_day
    in_april do
      url = calendar_chart.entries.detect { |entry| entry.key == Date.new(2026, 4, 2) }.url

      assert_equal ['><', %w[2026-04-02 2026-04-02]], url_filter(url, 'created_on')
    end
  end

  private

  def calendar_chart(**settings)
    settings = { group_by: 'created_on', chart_type: 'calendar' }.merge settings
    Additionals::TestIssueQueryChart.new project: @project, settings:
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
