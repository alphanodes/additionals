# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# What a chart block of a query shows and what programs read of it: the
# values of its table of values
class QueryChartBlockDataTest < Additionals::TestCase
  # A chart that refuses to add up its values, e.g. amounts of different currencies
  class UnavailableIssueQueryChart < Additionals::TestIssueQueryChart
    def unavailable_text
      'Different currencies'
    end
  end

  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_data_is_the_chart_of_the_stored_settings
    assert_equal 'tracker', block(group_by: 'tracker').data.group_column.name.to_s
  end

  def test_chart_blocks_export_data
    assert_predicate block_class('Additionals::TestIssueQueryChart'), :exports_data?
  end

  def test_export_has_a_row_per_entry
    chart = block(group_by: 'tracker').data

    assert_equal chart.entries.map(&:label), export(group_by: 'tracker')[:rows].map(&:first)
  end

  def test_export_has_the_values_of_the_entries
    chart = block(group_by: 'tracker').data

    assert_equal chart.entries.map(&:value), export(group_by: 'tracker')[:rows].map(&:last)
  end

  def test_export_names_the_group_and_the_measure
    assert_equal [I18n.t(:field_tracker), I18n.t(:label_quantity)], export(group_by: 'tracker')[:columns]
  end

  def test_export_has_the_total
    assert_equal [block(group_by: 'tracker').data.total], export(group_by: 'tracker')[:totals]
  end

  def test_export_tells_what_the_chart_shows
    assert_equal block(group_by: 'tracker').data.summary, export(group_by: 'tracker')[:summary]
  end

  def test_split_export_has_a_value_per_column
    data = export group_by: 'tracker', split_by: 'status', chart_type: 'bar_vertical'

    assert_equal [data[:columns].size] * data[:rows].size, data[:rows].map(&:size)
  end

  # Programs read periods as dates instead of a label in the language of the user
  def test_timeline_export_starts_its_rows_with_the_period
    chart = block(group_by: 'created_on', interval: 'month').data

    assert_equal chart.entries.first.key.iso8601, export(group_by: 'created_on', interval: 'month')[:rows].first.first
  end

  def test_timeline_export_names_its_interval
    assert_equal 'month', export(group_by: 'created_on', interval: 'month')[:interval]
  end

  def test_chart_without_group_exports_no_data
    assert_nil export(group_by: 'no_such_column')
  end

  def test_unavailable_chart_exports_why_instead_of_values
    data = block_class('QueryChartBlockDataTest::UnavailableIssueQueryChart')
           .new(DashboardContentProject.new(project: @project), settings: { group_by: 'tracker' }).export_data

    assert_equal({ summary: data[:summary], unavailable: 'Different currencies' }, data)
  end

  private

  def block_class(chart_name)
    Class.new(DashboardBlocks::QueryChartBlock) { chart chart_name }
  end

  def block(**settings)
    block_class('Additionals::TestIssueQueryChart').new DashboardContentProject.new(project: @project), settings:
  end

  def export(**settings)
    block(**settings).export_data
  end
end
