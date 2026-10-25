# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A number column groups by classes of its values, bounded by the setting or
# automatically
class AdditionalsQueryChartClassesTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
    @issues = Issue.where(project: @project).order(:id).first 3
    Issue.update_all estimated_hours: nil
    estimate @issues[0], 2
    estimate @issues[1], 12
    estimate @issues[2], 30
  end

  def test_group_options_contain_a_number_column
    assert_includes group_names(classes_chart), 'estimated_hours'
  end

  def test_group_options_contain_a_number_field
    field = integer_field

    assert_includes group_names(classes_chart), "cf_#{field.id}"
  end

  def test_split_options_do_not_contain_a_number_column
    assert_not_includes classes_chart.split_options.map(&:last), 'estimated_hours'
  end

  def test_number_column_has_classes
    assert_predicate classes_chart, :number_classes?
  end

  def test_number_groups_contain_a_number_column
    assert_includes classes_chart.number_group_names, 'estimated_hours'
  end

  def test_counts_the_entries_per_class
    assert_equal [1, 1, 1], class_values(classes_chart)
  end

  def test_classes_without_entries_keep_their_place
    estimate @issues[1], 3

    assert_equal [2, 0, 1], class_values(classes_chart)
  end

  def test_entries_without_a_value_are_a_class_of_their_own
    assert_includes classes_chart(show_empty: '1').entries.map(&:key), nil
  end

  def test_entries_without_a_value_can_be_left_out
    assert_not_includes classes_chart(show_empty: '0').entries.map(&:key), nil
  end

  def test_sums_up_a_column_per_class
    assert_in_delta 30, classes_chart(measure: 'estimated_hours').entries.detect { |entry| entry.key == 2 }.value
  end

  def test_bounds_take_a_decimal_comma
    assert_equal [2.5, 10.0], classes_chart(classes: '2,5; 10').class_bounds
  end

  def test_bounds_are_sorted
    assert_equal [10.0, 20.0], classes_chart(classes: '20, 10').class_bounds
  end

  def test_automatic_bounds_are_round_steps_over_all_values
    assert_equal [10, 20, 30], classes_chart(classes: '').class_bounds
  end

  # A class is no "Others" and no order by value: all classes always show
  def test_max_entries_does_not_drop_classes
    assert_equal 3, classes_chart(max_entries: '1', show_empty: '0').entries.size
  end

  def test_label_of_the_first_class
    I18n.with_locale :en do
      assert_equal 'below 10', classes_chart.entries.first.label
    end
  end

  def test_label_of_a_middle_class
    I18n.with_locale :en do
      assert_equal '10 to below 20', classes_chart.entries.second.label
    end
  end

  def test_label_of_the_last_class
    I18n.with_locale :en do
      assert_equal '20 and above', classes_chart(show_empty: '0').entries.last.label
    end
  end

  def test_url_of_the_first_class
    assert_equal ['<=', ['9.999999']], url_filter(classes_chart.entries.first.url, 'estimated_hours')
  end

  # The filters know no "below", the upper bound stays just below
  def test_url_of_a_middle_class_of_decimals
    assert_equal ['><', %w[10 19.999999]], url_filter(classes_chart.entries.second.url, 'estimated_hours')
  end

  def test_url_of_a_middle_class_of_integers
    field = integer_field
    [[0, 3], [1, 12], [2, 30]].each { |index, value| CustomValue.create! custom_field: field, customized: @issues[index], value: }
    chart = classes_chart group_by: "cf_#{field.id}"

    assert_equal ['><', %w[10 19]], url_filter(chart.entries.second.url, "cf_#{field.id}")
  end

  def test_url_of_the_last_class
    assert_equal ['>=', ['20']], url_filter(classes_chart(show_empty: '0').entries.last.url, 'estimated_hours')
  end

  def test_url_of_entries_without_a_value
    url = classes_chart.entries.detect { |entry| entry.key.nil? }.url

    assert_equal '!*', url_filter(url, 'estimated_hours').first
  end

  def test_splits_the_classes
    with_settings display_subprojects_issues: '0' do
      chart = classes_chart split_by: 'tracker', chart_type: 'bar_vertical'

      assert_equal({ @issues[0].tracker => 1 }, chart.entries.first.parts)
    end
  end

  def test_groups_by_a_number_field
    field = integer_field
    CustomValue.create! custom_field: field, customized: @issues[0], value: '15'

    assert_equal 1, classes_chart(group_by: "cf_#{field.id}", show_empty: '0').entries.second.value
  end

  # The expression of a custom field is long, its keys are read all the same
  def test_sums_up_a_column_per_class_of_a_number_field
    field = integer_field
    CustomValue.create! custom_field: field, customized: @issues[1], value: '15'
    chart = classes_chart group_by: "cf_#{field.id}", measure: 'estimated_hours', show_empty: '0'

    assert_in_delta 12, chart.entries.second.value
  end

  def test_splits_the_classes_of_a_number_field
    field = integer_field
    CustomValue.create! custom_field: field, customized: @issues[1], value: '15'
    chart = classes_chart group_by: "cf_#{field.id}", split_by: 'tracker', show_empty: '0'

    assert_equal({ @issues[1].tracker => 1 }, chart.entries.second.parts)
  end

  # Without any value there are no bounds to build classes from, only the
  # entries without a value remain
  def test_no_classes_without_values
    Issue.update_all estimated_hours: nil

    assert_equal [nil], classes_chart(classes: '').entries.map(&:key)
  end

  # Whole numbers know no bound between two of them
  def test_bounds_of_whole_numbers_round_up
    field = integer_field
    CustomValue.create! custom_field: field, customized: @issues[0], value: '2'
    chart = classes_chart group_by: "cf_#{field.id}", classes: '2.5; 10'

    assert_equal ['<=', ['2']], url_filter(chart.entries.first.url, "cf_#{field.id}")
  end

  # Whole numbers name the last value of a class as its link filters it, a
  # class of one value names that one; the first and the last stay open
  def test_labels_of_whole_numbers_name_their_last_value
    field = integer_field
    CustomValue.create! custom_field: field, customized: @issues[0], value: '2'
    chart = classes_chart group_by: "cf_#{field.id}", classes: '-7; 0; 1; 8', show_empty: '0'

    I18n.with_locale :en do
      assert_equal ['below -7', '-7 to -1', '0', '1 to 7', '8 and above'], chart.entries.map(&:label)
    end
  end

  # A span below 5 has steps below 1: they stay decimals, the database
  # compares them as such (PostgreSQL divided 3/2 as integers)
  def test_automatic_bounds_below_one_are_decimals
    Issue.update_all estimated_hours: nil
    issues = Issue.where(project: @project).order(:id).first 5
    [0.5, 1, 1.5, 2, 2.5].each_with_index { |hours, index| estimate issues[index], hours }
    chart = classes_chart classes: ''

    assert_equal [1.0, 1.5, 2.0, 2.5], chart.class_bounds
    assert(chart.class_bounds.all?(Float))
    assert_equal [1, 1, 1, 1, 1], class_values(chart)
  end

  def test_bounds_of_decimals_stay
    assert_equal [2.5, 10.0], classes_chart(classes: '2.5; 10').class_bounds
  end

  # Each class is one more query when summed up
  def test_classes_given_are_limited
    bounds = (1..200).to_a.join '; '

    assert_equal AdditionalsQueryChart::MAX_CLASSES, classes_chart(classes: bounds).class_bounds.size
  end

  # A filter does not read 1.0e-06
  def test_url_of_a_class_below_zero
    assert_equal ['<=', ['-0.000001']], url_filter(classes_chart(classes: '0, 10').entries.first.url, 'estimated_hours')
  end

  private

  def classes_chart(**settings)
    settings = { group_by: 'estimated_hours', classes: '10, 20', chart_type: 'bar_vertical' }.merge settings
    Additionals::TestIssueQueryChart.new project: @project, settings:
  end

  def estimate(issue, hours)
    Issue.where(id: issue.id).update_all estimated_hours: hours
  end

  def class_values(chart)
    chart.entries.filter_map { |entry| entry.value if entry.key }
  end

  def integer_field
    IssueCustomField.create! name: 'Story points', field_format: 'int', is_for_all: true, is_filter: true,
                             tracker_ids: Tracker.ids
  end

  def group_names(chart)
    chart.group_options.map(&:last)
  end

  def url_filter(url, field)
    params = Rack::Utils.parse_nested_query URI(url).query
    [params['op'][field], params['v'][field]]
  end
end
