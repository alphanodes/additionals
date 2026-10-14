# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsQueryChartTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_counts_the_entries_of_a_group
    with_settings display_subprojects_issues: '0' do
      entry = issue_chart(group_by: 'tracker').entries.detect { |e| e.key == trackers(:trackers_001) }

      assert_equal Issue.where(project: @project, tracker_id: 1).count, entry.value
    end
  end

  # IssueQuery filters open issues by default, the block without a query does not

  def test_without_query_counts_closed_issues_too
    with_settings display_subprojects_issues: '0' do
      assert_equal Issue.where(project: @project).count, issue_chart(group_by: 'tracker').total
    end
  end

  def test_sums_up_a_totalable_column
    Issue.where(project: @project, tracker_id: 1).update_all estimated_hours: 2.5

    with_settings display_subprojects_issues: '0' do
      entry = issue_chart(group_by: 'tracker', measure: 'estimated_hours').entries.detect { |e| e.key == trackers(:trackers_001) }

      assert_in_delta Issue.where(project: @project, tracker_id: 1).count * 2.5, entry.value
    end
  end

  def test_a_field_with_multiple_values_counts_each_value
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]
    add_values field, issues(:issues_002), %w[A]

    assert_equal({ 'A' => 2, 'B' => 1 }, entry_values(issue_chart(group_by: "cf_#{field.id}", show_empty: '0')))
  end

  def test_a_field_with_multiple_values_counts_the_entries_without_value
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A]

    with_settings display_subprojects_issues: '0' do
      entry = issue_chart(group_by: "cf_#{field.id}").entries.detect { |e| e.key.nil? }

      assert_equal Issue.where(project: @project).count - 1, entry.value
    end
  end

  # Like the grouping of core: values of a field visible to other roles stay hidden

  def test_a_field_with_multiple_values_counts_visible_values_only
    field = multiple_list_field
    field.update! visible: false, role_ids: [roles(:roles_001).id]
    add_values field, issues(:issues_001), %w[B]
    # jsmith is manager in ecookbook, but developer in onlinestore
    add_values field, issues(:issues_004), %w[A]
    User.current = users :users_002
    chart = Additionals::TestIssueQueryChart.new project: nil, settings: { group_by: "cf_#{field.id}" }

    assert_equal ['B', nil], chart.entries.map(&:key)
  end

  # A sum would count an entry once for each of its values

  def test_a_field_with_multiple_values_is_always_counted
    field = multiple_list_field

    assert_nil issue_chart(group_by: "cf_#{field.id}", measure: 'estimated_hours').measure_column
  end

  def test_entries_without_value_can_be_hidden
    chart = issue_chart group_by: 'category', show_empty: '0'

    assert_not(chart.entries.any? { |e| e.key.nil? })
  end

  def test_entries_without_value_are_shown_by_default
    assert(issue_chart(group_by: 'category').entries.any? { |e| e.key.nil? })
  end

  def test_order_of_the_field_follows_the_position
    keys = issue_chart(group_by: 'tracker').entries.map(&:key)

    assert_equal keys.sort_by(&:position), keys
  end

  def test_order_by_value_shows_the_largest_value_first
    values = issue_chart(group_by: 'tracker', order: 'value').entries.map(&:value)

    assert_equal values.max(values.size), values
  end

  def test_max_entries_sums_up_the_rest_as_others
    chart = issue_chart group_by: 'tracker'
    all_values = chart.entries.map(&:value).max(chart.entries.size)
    limited = issue_chart group_by: 'tracker', max_entries: '1'

    assert_equal [all_values.first, all_values.drop(1).sum], limited.entries.map(&:value)
  end

  def test_max_entries_labels_the_rest_as_others
    limited = issue_chart group_by: 'tracker', max_entries: '1'

    assert_equal I18n.t(:label_chart_others), limited.entries.last.label
  end

  def test_url_filters_by_the_value_of_the_entry
    entry = issue_chart(group_by: 'tracker').entries.detect { |e| e.key == trackers(:trackers_001) }

    assert_includes CGI.unescape(entry.url), 'v[tracker_id][]=1'
  end

  def test_url_of_entries_without_value_filters_for_none
    entry = issue_chart(group_by: 'category').entries.detect { |e| e.key.nil? }

    assert_includes CGI.unescape(entry.url), 'op[category_id]=!*'
  end

  def test_url_of_others_is_empty
    limited = issue_chart group_by: 'tracker', max_entries: '1'

    assert_nil limited.entries.last.url
  end

  def test_group_options_contain_lists
    assert_includes group_names(issue_chart), 'tracker'
  end

  # The filter of the assignee is an autocomplete type of additionals, not a list

  def test_group_options_contain_the_assignee
    assert_includes group_names(issue_chart), 'assigned_to'
  end

  def test_group_options_do_not_contain_dates
    assert_not_includes group_names(issue_chart), 'start_date'
  end

  def test_group_options_contain_fields_with_multiple_values
    field = multiple_list_field

    assert_includes group_names(issue_chart), "cf_#{field.id}"
  end

  # The old field charts showed fields that are no filter, so the block does too

  def test_a_field_that_is_no_filter_can_be_grouped
    field = multiple_list_field
    field.update! is_filter: false

    assert_includes group_names(issue_chart), "cf_#{field.id}"
  end

  def test_a_field_that_is_no_filter_has_no_url
    field = multiple_list_field
    field.update! is_filter: false
    add_values field, issues(:issues_001), %w[A]

    assert_nil issue_chart(group_by: "cf_#{field.id}").entries.first.url
  end

  # Otherwise the settings of the block could not be saved anymore

  def test_deleted_query_still_offers_the_groups
    assert_includes group_names(issue_chart(query_id: '0')), 'tracker'
  end

  def test_version_of_another_project_carries_the_project
    version = versions :versions_002
    chart = Additionals::TestIssueQueryChart.new project: nil, settings: { group_by: 'fixed_version' }
    entry = chart.entries.detect { |e| e.key == version }

    assert_equal "#{version.project} - #{version}", entry.label
  end

  def test_unknown_group_has_no_entries
    assert_empty issue_chart(group_by: 'start_date').entries
  end

  def test_query_of_another_user_has_no_entries
    query = IssueQuery.create! name: 'Private', user: users(:users_002), visibility: Query::VISIBILITY_PRIVATE
    User.current = users :users_003

    assert_empty issue_chart(group_by: 'tracker', query_id: query.id.to_s).entries
  end

  def test_compare_shows_the_second_query_next_to_the_first
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                               filters: { 'tracker_id' => { operator: '=', values: ['1'] },
                                          'status_id' => { operator: '*', values: [''] } }
    chart = issue_chart group_by: 'tracker', compare_query_id: query.id.to_s, chart_type: 'bar_horizontal'
    entry = chart.entries.detect { |e| e.key == trackers(:trackers_001) }

    assert_equal entry.value, entry.compare_value
  end

  # A click on a bar of the second series shows the issues of the second query

  def test_compare_links_the_values_of_the_second_query
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                               filters: { 'priority_id' => { operator: '=', values: ['4'] } }
    chart = issue_chart group_by: 'tracker', compare_query_id: query.id.to_s, chart_type: 'bar_horizontal'
    entry = chart.entries.detect { |e| e.key == trackers(:trackers_001) }

    assert_includes CGI.unescape(entry.compare_url), 'v[priority_id][]=4'
  end

  def test_compare_is_not_shown_in_a_pie
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC

    assert_not issue_chart(group_by: 'tracker', compare_query_id: query.id.to_s, chart_type: 'pie').compare?
  end

  def test_payload_has_a_dataset_per_series
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC
    chart = issue_chart group_by: 'tracker', compare_query_id: query.id.to_s, chart_type: 'bar_vertical'

    assert_equal 2, chart.payload[:datasets].size
  end

  def test_unknown_chart_type_falls_back_to_doughnut
    assert_equal 'doughnut', issue_chart(group_by: 'tracker', chart_type: 'radar').chart_type
  end

  def test_table_only_always_shows_the_table
    assert_predicate issue_chart(group_by: 'tracker', chart_type: 'table', with_table: '0'), :with_table?
  end

  def test_title_names_the_group
    assert_equal "#{I18n.t :label_issue_plural}#{Additionals::LIST_SEPARATOR}#{I18n.t :label_tracker}",
                 issue_chart(group_by: 'tracker').title
  end

  def test_dashboard_block_renders_the_chart_partial
    assert_equal 'dashboards/blocks/query_chart', Additionals::TestIssueQueryChart.dashboard_block(label: 'Chart')[:async][:partial]
  end

  def test_dashboard_block_keeps_given_options
    assert_equal :view_issues, Additionals::TestIssueQueryChart.dashboard_block(label: 'Chart', permission: :view_issues)[:permission]
  end

  private

  def issue_chart(**settings)
    Additionals::TestIssueQueryChart.new project: @project, settings:
  end

  def group_names(chart)
    chart.group_options.map(&:last)
  end

  def entry_values(chart)
    chart.entries.to_h { |entry| [entry.key, entry.value] }
  end

  def multiple_list_field
    IssueCustomField.create! name: 'Platforms',
                             field_format: 'list',
                             possible_values: %w[A B C],
                             multiple: true,
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
