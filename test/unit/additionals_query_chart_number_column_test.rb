# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A number computed by SQL groups in classes like a stored one, with colors
# by direction where values below and above 0 mean opposites
class AdditionalsQueryChartNumberColumnTest < Additionals::TestCase
  # The estimate against 10 hours: below is less, above more
  class NumberIssueQuery < IssueQuery
    SQL = "#{Issue.table_name}.estimated_hours - 10".freeze

    def available_columns
      super + [QueryNumberColumn.new(:estimate_gap, sql: SQL, diverging: true, classes: [-5, 0, 1, 10],
                                                    caption: :field_estimated_hours)]
    end

    def initialize_available_filters
      super
      add_available_filter 'estimate_gap', type: :float, name: 'Estimate gap'
    end

    def sql_for_estimate_gap_field(_field, operator, value)
      case operator
      when '!*' then "(#{SQL}) IS NULL"
      when '*' then "(#{SQL}) IS NOT NULL"
      when '<=' then "(#{SQL}) <= #{value.first.to_f}"
      when '>=' then "(#{SQL}) >= #{value.first.to_f}"
      else "(#{SQL}) BETWEEN #{value.first.to_f} AND #{value.last.to_f}"
      end
    end
  end

  class NumberChart < Additionals::TestIssueQueryChart
    def query_class
      NumberIssueQuery
    end
  end

  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    Issue.update_all estimated_hours: nil
    issues = Issue.where(project: @project).order(:id).first 3
    [2, 10, 30].each_with_index { |hours, index| Issue.where(id: issues[index].id).update_all estimated_hours: hours }
  end

  def test_a_computed_number_has_classes
    assert_predicate chart, :number_classes?
    assert_includes chart.group_options.map(&:last), 'estimate_gap'
  end

  # -8, 0 and 20 hours against the bounds -5; 0; 1; 10
  def test_counts_the_entries_per_class_of_the_computed_number
    assert_equal([1, 0, 1, 0, 1], chart.entries.filter_map { |entry| entry.value if entry.key })
  end

  def test_links_a_class_by_the_filter_of_the_computed_number
    url = chart.entries.detect { |entry| entry.key.zero? }.url
    params = Rack::Utils.parse_nested_query URI(url).query

    assert_equal ['<=', ['-5.000001']], [params['op']['estimate_gap'], params['v']['estimate_gap']]
  end

  # Below 0 blue, the class of 0 gray, above red, without a value light gray
  def test_colors_the_classes_by_direction
    assert_equal ['--oc-blue-6', '--oc-blue-6', '--oc-gray-5', '--oc-red-6', '--oc-red-6', '--oc-gray-3'],
                 chart(show_empty: '1').payload[:datasets].first[:colors]
  end

  # Compared with another query, the second series keeps the color of the scheme
  def test_compared_series_has_no_colors_by_direction
    query = NumberIssueQuery.create! name: 'All', project: @project, user: User.current, visibility: IssueQuery::VISIBILITY_PUBLIC
    datasets = chart(compare_query_id: query.id.to_s).payload[:datasets]

    assert_equal [true, nil], [datasets.first[:colors].present?, datasets.second[:colors]]
  end

  # The bars tell their share as the table does
  def test_bars_tell_their_share
    chart = chart()

    I18n.with_locale :en do
      assert_equal(chart.entries.map { |entry| "Percentage: #{chart.share entry} %" }, chart.payload[:datasets].first[:tooltips])
    end
  end

  # Without bounds of its own the chart takes those of the column, not
  # automatic ones over the values
  def test_without_bounds_the_classes_of_the_column
    assert_equal [-5, 0, 1, 10], chart(classes: '').class_bounds
  end

  # Other plugins may add columns with classes of their own to the query
  def test_the_form_knows_the_classes_of_the_column
    assert_equal ['-5; 0; 1; 10', nil], chart.default_classes.values_at('estimate_gap', 'estimated_hours')
  end

  def test_no_colors_by_direction_for_other_numbers
    settings = { group_by: 'estimated_hours', classes: '5; 20', chart_type: 'bar_vertical' }

    assert_nil NumberChart.new(project: @project, settings:).payload[:datasets].first[:colors]
  end

  private

  def chart(**settings)
    settings = { group_by: 'estimate_gap', classes: '-5; 0; 1; 10', chart_type: 'bar_vertical' }.merge settings
    NumberChart.new project: @project, settings:
  end
end
