# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CustomFieldNumberListFormatTest < Additionals::TestCase
  def setup
    User.current = users :users_001
    @field = IssueCustomField.create! name: 'Size', field_format: 'number_list', is_for_all: true, is_filter: true,
                                      trackers: Tracker.all, possible_values: %w[1 2 3 5 8 13 0.5]
  end

  def test_format_is_a_list_of_single_numbers_with_totals
    format = Redmine::FieldFormat.find 'number_list'

    assert_equal 'label_number_list', format.label
    assert format.totalable_supported
    assert_not format.multiple_supported
    assert_not format.searchable_supported
  end

  def test_possible_values_must_be_distinct_numbers
    { %w[1 2 3] => true, %w[1 two 3] => false, %w[1 1.0 2] => false, %w[0.5 -1 1.25] => true }.each do |values, valid|
      field = IssueCustomField.new name: "Size #{values.join}", field_format: 'number_list', possible_values: values

      assert_equal valid, field.valid?, values.inspect
    end
  end

  def test_value_has_to_be_in_the_list
    assert_empty @field.validate_field_value('8')
    assert_not_empty @field.validate_field_value('7')
  end

  def test_values_are_numbers
    assert_equal [13, 0.5, nil], [@field.cast_value('13'), @field.cast_value('0.5'), @field.cast_value('')]
  end

  def test_values_show_in_the_language_of_the_user
    I18n.with_locale :de do
      assert_equal %w[0,5 13], [@field.format.formatted_value(nil, @field, '0.5'),
                                @field.format.formatted_value(nil, @field, '13')]
      assert_includes @field.format.possible_values_options(@field), ['0,5', '0.5']
    end

    I18n.with_locale :en do
      assert_equal '0.5', @field.format.formatted_value(nil, @field, '0.5')
    end
  end

  # Prefix and suffix, text and icon, on pages and lists only: selections,
  # exports and APIs get the plain number
  def test_prefix_and_suffix_show_in_html_only
    @field.update! value_prefix: '<b>', value_prefix_icon: 'star', value_suffix: 'SP', value_suffix_icon: 'coins'
    html = @field.format.formatted_value build_redmine_view, @field, '5', nil, true

    assert_predicate html, :html_safe?
    assert_match(/icon--star.*&lt;b&gt; 5 SP.*icon--coins/m, html)
    # Classes for themes: the value and both icons can be styled on their own
    assert_match(/\A<span class="number-list-value number-list-value-5">/, html)
    assert_match(/class="[^"]*number-list-prefix-icon[^"]*".*class="[^"]*number-list-suffix-icon/m, html)
    assert_equal 'number-list-value-0-5', Redmine::FieldFormat::NumberListFormat.css_class('0.5')
    assert_equal '5', @field.format.formatted_value(build_redmine_view, @field, '5', nil, false)
    assert_includes @field.format.possible_values_options(@field), %w[5 5]
  end

  # A value removed from the list stays selectable where it is set
  def test_removed_value_stays_selectable_on_its_object
    issue = issues :issues_001
    custom_value = CustomFieldValue.new custom_field: @field, customized: issue, value: '21'

    assert_equal %w[21 21], @field.format.possible_custom_value_options(custom_value).last
  end

  def test_query_totals_sorts_and_groups_as_numbers
    set_value issues(:issues_001), '13'
    set_value issues(:issues_002), '2'
    set_value issues(:issues_003), '0.5'
    column = :"cf_#{@field.id}"

    query = IssueQuery.new name: '_', totalable_names: [column], sort_criteria: [[column.to_s, 'asc']]
    query.add_filter "cf_#{@field.id}", '*', ['']

    assert_in_delta 15.5, query.total_for(column)
    assert_equal [3, 2, 1], query.issues.map(&:id)

    query.group_by = column.to_s

    assert_equal [0.5, 2, 13], query.result_count_by_group.keys
  end

  private

  def set_value(issue, value)
    issue.custom_field_values = { @field.id.to_s => value }
    issue.save!
  end
end
