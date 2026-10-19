# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# A second column splits each entry into parts, shown as stacked bars or as a
# cross table
class AdditionalsQueryChartSplitTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_splits_the_entries_by_the_second_column
    with_settings display_subprojects_issues: '0' do
      entry = tracker_entry split_chart

      assert_equal(Issue.where(project: @project, tracker_id: 1).group(:status).count, entry.parts)
    end
  end

  def test_parts_add_up_to_the_value_of_the_entry
    entry = tracker_entry split_chart

    assert_equal entry.value, entry.parts.values.sum
  end

  # The table of the block and programs read the same columns
  def test_table_has_a_cell_per_value_column
    chart = split_chart

    assert_equal chart.value_columns.size, chart.entry_cells(tracker_entry(chart)).size
  end

  def test_table_has_a_total_per_value_column
    chart = split_chart

    assert_equal chart.value_columns.size, chart.value_totals.size
  end

  def test_split_keys_follow_the_order_of_the_field
    field = list_field
    add_values field, issues(:issues_001), %w[C]
    add_values field, issues(:issues_002), %w[A]

    assert_equal %w[A C], split_chart(split_by: "cf_#{field.id}", show_empty: '0').split_keys
  end

  def test_split_by_a_user_field_has_users_as_keys
    field = IssueCustomField.create! name: 'Split user', field_format: 'user', is_for_all: true,
                                     is_filter: true, tracker_ids: Tracker.ids
    add_values field, issues(:issues_001), [users(:users_002).id.to_s]

    assert_equal [users(:users_002)], split_chart(split_by: "cf_#{field.id}", show_empty: '0').split_keys
  end

  # The users of the keys come in one query, not one per user
  def test_split_by_a_user_field_loads_the_users_at_once
    field = IssueCustomField.create! name: 'Split users', field_format: 'user', is_for_all: true,
                                     is_filter: true, tracker_ids: Tracker.ids
    one = user_split_queries field, [users(:users_002)]
    three = user_split_queries field, [users(:users_002), users(:users_003), users(:users_004)]

    assert_equal one, three
  end

  def test_group_by_a_multiple_user_field_loads_the_users_at_once
    field = IssueCustomField.create! name: 'Group users', field_format: 'user', multiple: true, is_for_all: true,
                                     is_filter: true, tracker_ids: Tracker.ids
    add_values field, issues(:issues_001), [users(:users_002).id.to_s]
    one = user_queries { split_chart(group_by: "cf_#{field.id}", split_by: '', show_empty: '0').entries }
    add_values field, issues(:issues_002), [users(:users_003).id.to_s, users(:users_004).id.to_s]
    three = user_queries { split_chart(group_by: "cf_#{field.id}", split_by: '', show_empty: '0').entries }

    assert_equal one, three
  end

  # A column of an own class may map its keys itself, which a split would bypass
  def test_a_column_of_an_own_class_cannot_split
    column = Class.new(QueryColumn).new :own, groupable: true

    assert_not split_chart.send(:split_column?, column)
  end

  def test_group_by_a_field_with_multiple_values_and_split_explains_the_total
    field = list_field multiple: true
    add_values field, issues(:issues_001), %w[A B]

    assert_predicate split_chart(group_by: "cf_#{field.id}", split_by: 'tracker'), :counted_several_times?
  end

  def test_split_by_a_field_with_multiple_values_explains_the_parts
    field = list_field multiple: true
    add_values field, issues(:issues_001), %w[A B]

    assert_predicate split_chart(split_by: "cf_#{field.id}"), :parts_counted_several_times?
  end

  # Sums are rounded per part and could add up to more than the entry
  def test_split_with_a_sum_does_not_explain_the_parts
    Issue.where(project: @project).update_all estimated_hours: 0.005

    assert_not split_chart(measure: 'estimated_hours').parts_counted_several_times?
  end

  def test_others_entry_of_a_split_has_no_part_urls
    chart = split_chart max_entries: '1'

    assert_empty chart.entries.last.part_urls
  end

  def test_split_by_a_custom_field
    field = list_field
    add_values field, issues(:issues_001), %w[B]

    assert_equal({ 'B' => 1 }, tracker_entry(split_chart(split_by: "cf_#{field.id}", show_empty: '0')).parts)
  end

  def test_split_by_a_field_with_multiple_values_counts_each_value
    field = list_field multiple: true
    add_values field, issues(:issues_001), %w[A B]

    assert_equal({ 'A' => 1, 'B' => 1 }, tracker_entry(split_chart(split_by: "cf_#{field.id}", show_empty: '0')).parts)
  end

  def test_group_by_a_field_with_multiple_values_and_split
    field = list_field multiple: true
    add_values field, issues(:issues_001), %w[A B]
    chart = split_chart group_by: "cf_#{field.id}", split_by: 'tracker', show_empty: '0'

    assert_equal({ trackers(:trackers_001) => 1 }, chart.entries.detect { |entry| entry.key == 'B' }.parts)
  end

  # Two fields with multiple values would need two joins of their values
  def test_two_fields_with_multiple_values_do_not_split
    field = list_field multiple: true
    other = list_field multiple: true

    assert_not split_chart(group_by: "cf_#{field.id}", split_by: "cf_#{other.id}").split?
  end

  def test_split_sums_up_a_totalable_column
    Issue.where(project: @project, tracker_id: 1).update_all estimated_hours: 2

    with_settings display_subprojects_issues: '0' do
      parts = tracker_entry(split_chart(measure: 'estimated_hours')).parts

      assert_in_delta Issue.where(project: @project, tracker_id: 1).count * 2, parts.values.sum
    end
  end

  def test_split_without_empty_values_drops_them
    field = list_field
    add_values field, issues(:issues_001), %w[A]
    chart = split_chart split_by: "cf_#{field.id}", show_empty: '0'

    assert_equal ['A'], chart.split_keys
  end

  def test_split_with_empty_values_keeps_them_last
    field = list_field
    add_values field, issues(:issues_001), %w[A]
    chart = split_chart split_by: "cf_#{field.id}"

    assert_equal ['A', nil], chart.split_keys
  end

  # The list shows NULL and an empty string as one group without value
  def test_split_counts_an_empty_string_as_no_value
    chart = split_chart

    assert_nil chart.send(:split_key_mapper, Issue, QueryColumn.new(:subject), 'subject', [''])['']
  end

  def test_title_names_the_split
    captions = %i[label_issue_plural field_tracker field_status].map { |key| ::I18n.t key }

    assert_equal captions.join(Additionals::LIST_SEPARATOR), split_chart.title
  end

  def test_pie_does_not_split
    assert_not split_chart(chart_type: 'doughnut').split?
  end

  def test_table_splits
    assert_predicate split_chart(chart_type: 'table'), :split?
  end

  def test_same_column_does_not_split
    assert_not split_chart(split_by: 'tracker').split?
  end

  def test_split_replaces_the_comparison
    query = IssueQuery.create! name: 'Compare', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC

    assert_not split_chart(compare_query_id: query.id.to_s).compare?
  end

  def test_payload_has_a_stacked_dataset_per_split_value
    chart = split_chart

    assert_equal chart.split_keys.map(&:name), chart.payload[:datasets].pluck(:label)
  end

  def test_payload_is_stacked
    assert split_chart.payload[:stacked]
  end

  def test_url_of_a_part_filters_by_both_values
    status = issue_statuses :issue_statuses_001
    url = tracker_entry(split_chart).part_urls[status]

    assert_equal [%w[1], %w[1]], url_values(url, %w[tracker_id status_id])
  end

  def test_url_of_an_entry_does_not_filter_by_the_split
    url = tracker_entry(split_chart).url

    assert_nil Rack::Utils.parse_nested_query(URI(url).query)['op']['status_id']
  end

  def test_legend_of_a_split_adds_to_the_height
    assert_operator split_chart.height, :>, split_chart(split_by: '').height
  end

  def test_url_of_a_part_without_value_filters_for_none
    field = list_field
    field.update! is_filter: true
    add_values field, issues(:issues_001), %w[A]
    url = tracker_entry(split_chart(split_by: "cf_#{field.id}")).part_urls[nil]

    assert_equal '!*', Rack::Utils.parse_nested_query(URI(url).query)['op']["cf_#{field.id}"]
  end

  def test_min_share_sums_up_small_split_values_as_others
    chart = split_chart min_share: '30'
    others = chart.split_keys.last

    assert_equal AdditionalsQueryChart::OTHERS, others
  end

  def test_others_of_the_split_have_no_url
    entry = tracker_entry split_chart(min_share: '30')

    assert_nil entry.part_urls[AdditionalsQueryChart::OTHERS]
  end

  def test_others_entry_sums_up_the_parts
    chart = split_chart max_entries: '1'
    others = chart.entries.last

    assert_equal others.value, others.parts.values.sum
  end

  private

  def user_split_queries(field, users)
    CustomValue.where(custom_field: field).delete_all
    users.each_with_index { |user, index| add_values field, Issue.where(project: @project).order(:id).to_a[index], [user.id.to_s] }
    user_queries { split_chart(split_by: "cf_#{field.id}", show_empty: '0').entries }
  end

  def user_queries(&)
    count_sql_queries(matching: /FROM .users. WHERE/, &)
  end

  def split_chart(**settings)
    settings = { group_by: 'tracker', split_by: 'status', chart_type: 'bar_horizontal' }.merge settings
    Additionals::TestIssueQueryChart.new project: @project, settings:
  end

  def tracker_entry(chart)
    chart.entries.detect { |entry| entry.key == trackers(:trackers_001) }
  end

  def url_values(url, fields)
    values = Rack::Utils.parse_nested_query(URI(url).query)['v']
    fields.map { |field| values[field] }
  end

  def list_field(multiple: false)
    IssueCustomField.create! name: "Split #{IssueCustomField.count}",
                             field_format: 'list',
                             possible_values: %w[A B C],
                             multiple:,
                             is_for_all: true,
                             is_filter: true,
                             tracker_ids: Tracker.ids
  end

  def add_values(field, issue, values)
    values.each do |value|
      CustomValue.create! custom_field: field, customized: issue, value:
    end
  end
end
