# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsQueryChartTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_a_chart_unavailable_for_its_settings_is_not_valid
    unavailable = Class.new Additionals::TestIssueQueryChart do
      def unavailable_text = 'Not with these settings'
    end

    assert_not unavailable.new(project: @project, settings: { group_by: 'tracker' }).valid?
  end

  def test_a_chart_is_available_by_default
    assert_nil issue_chart(group_by: 'tracker').unavailable_text
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

  # The total matches the list the chart links to, an entry counts once

  def test_a_field_with_multiple_values_counts_each_entry_once_in_the_total
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]
    add_values field, issues(:issues_002), %w[A]

    assert_equal 2, issue_chart(group_by: "cf_#{field.id}", show_empty: '0').total
  end

  def test_total_of_a_field_with_multiple_values_includes_entries_without_value
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]

    with_settings display_subprojects_issues: '0' do
      assert_equal Issue.where(project: @project).count, issue_chart(group_by: "cf_#{field.id}").total
    end
  end

  def test_share_of_a_field_with_multiple_values_refers_to_the_entries
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]
    add_values field, issues(:issues_002), %w[A]
    chart = issue_chart group_by: "cf_#{field.id}", show_empty: '0'

    assert_equal 100, chart.share(chart.entries.detect { |entry| entry.key == 'A' })
  end

  def test_compare_total_of_a_field_with_multiple_values_counts_each_entry_once
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]
    query = IssueQuery.create! name: 'Compare', user: users(:users_001), project: @project,
                               visibility: Query::VISIBILITY_PUBLIC, filters: { 'status_id' => { operator: '*', values: [''] } }
    chart = issue_chart group_by: "cf_#{field.id}", show_empty: '0', chart_type: 'bar_horizontal', compare_query_id: query.id.to_s

    assert_equal 1, chart.compare_total
  end

  def test_entries_counted_several_times_are_recognized
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]

    assert_predicate issue_chart(group_by: "cf_#{field.id}"), :counted_several_times?
  end

  def test_entries_with_one_value_each_are_not_counted_several_times
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A]

    assert_not_predicate issue_chart(group_by: "cf_#{field.id}"), :counted_several_times?
  end

  def test_min_share_of_a_field_with_multiple_values_refers_to_the_entries
    field = multiple_list_field
    add_values field, issues(:issues_001), %w[A B]
    add_values field, issues(:issues_002), %w[A]

    # B has 1 of 2 entries (50 %), but only 1 of 3 values
    keys = issue_chart(group_by: "cf_#{field.id}", show_empty: '0', min_share: '40').entries.map(&:key)

    assert_equal %w[A B], keys
  end

  # A sum would count an entry once for each of its values

  def test_a_field_with_multiple_values_is_always_counted
    field = multiple_list_field

    assert_nil issue_chart(group_by: "cf_#{field.id}", measure: 'estimated_hours').measure_column
  end

  # The list shows NULL and an empty string as one group without value
  def test_an_empty_string_counts_as_no_value
    assert_equal({ nil => 3, 'A' => 1 }, issue_chart.send(:merge_blank_keys, { nil => 1, '' => 2, 'A' => 1 }))
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

  def test_treemap_names_the_rest_of_small_tiles
    I18n.with_locale :en do
      assert_equal 'Others', issue_chart(group_by: 'tracker', chart_type: 'treemap').payload[:restLabel]
    end
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

  def test_min_share_sums_up_smaller_values_as_others
    entries = issue_chart(group_by: 'tracker').entries
    share = smallest_share(entries) + 0.1
    expected = entries.select { |entry| entry.value * 100.0 / entries.sum(&:value) < share }.sum(&:value)
    others = issue_chart(group_by: 'tracker', min_share: share.to_s).entries.detect { |entry| entry.key == AdditionalsQueryChart::OTHERS }

    assert_equal expected, others&.value
  end

  # Unlike leaving them out, the total and the shares stay right
  def test_min_share_keeps_the_total
    entries = issue_chart(group_by: 'tracker').entries
    share = smallest_share(entries) + 0.1

    assert_equal entries.sum(&:value), issue_chart(group_by: 'tracker', min_share: share.to_s).total
  end

  def test_min_share_below_every_value_sums_up_nothing
    entries = issue_chart(group_by: 'tracker').entries

    assert_equal entries.map(&:key), issue_chart(group_by: 'tracker', min_share: '0.001').entries.map(&:key)
  end

  # Small values go first, max entries limits the rest
  def test_min_share_applies_before_max_entries
    entries = issue_chart(group_by: 'tracker').entries
    largest_share = entries.map(&:value).max * 100.0 / entries.sum(&:value)
    limited = issue_chart group_by: 'tracker', min_share: (largest_share - 0.1).to_s, max_entries: '5'

    assert_equal [entries.max_by(&:value).key, AdditionalsQueryChart::OTHERS], limited.entries.map(&:key)
  end

  def test_open_only_is_offered_with_a_label_for_default_filters
    assert_predicate project_chart(group_by: 'is_public'), :open_only_supported?
  end

  # A generic text could not tell the user what the option does
  def test_open_only_is_not_offered_without_a_label
    assert_not_predicate issue_chart(group_by: 'tracker'), :open_only_supported?
  end

  def test_open_only_applies_the_default_filters
    Project.generate!.update_column :status, Project::STATUS_CLOSED

    assert_equal Project.visible.where(status: Project::STATUS_ACTIVE).count,
                 project_chart(group_by: 'is_public', open_only: '1').total
  end

  # The filters of the query stay, the default filters restrict them further
  def test_open_only_adds_to_the_filters_of_a_query
    Project.generate!(is_public: false).update_column :status, Project::STATUS_CLOSED
    query = ProjectQuery.create! name: 'Private', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                 filters: { 'is_public' => { operator: '=', values: ['0'] },
                                            'status' => { operator: '*', values: [''] } }

    assert_equal Project.visible.where(is_public: false, status: Project::STATUS_ACTIVE).count,
                 project_chart(group_by: 'is_public', query_id: query.id.to_s, open_only: '1').total
  end

  def test_url_of_open_only_adds_the_default_filter
    entry = project_chart(group_by: 'is_public', open_only: '1').entries.first

    assert_equal ['1'], url_values(entry.url, 'status')
  end

  def test_url_of_open_only_joins_the_status_filter_of_the_query
    query = ProjectQuery.create! name: 'Active or closed', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                 filters: { 'status' => { operator: '=', values: %w[1 5] } }
    entry = project_chart(group_by: 'is_public', query_id: query.id.to_s, open_only: '1').entries.first

    assert_equal ['1'], url_values(entry.url, 'status')
  end

  # No list shows active projects that are not active
  def test_url_of_open_only_without_common_values_has_no_link
    query = ProjectQuery.create! name: 'Not active', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                 filters: { 'status' => { operator: '!', values: %w[1] } }
    compare = ProjectQuery.create! name: 'All', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                                   filters: { 'status' => { operator: '*', values: [''] } }
    entry = project_chart(group_by: 'is_public', query_id: query.id.to_s, compare_query_id: compare.id.to_s,
                          chart_type: 'bar_vertical', open_only: '1').entries.first

    assert_nil entry.url
  end

  # A project rule of its own would drop entries of subprojects a query
  # includes by its filter, if the setting shows no subproject issues
  def test_default_filters_bring_no_project_rule
    chart = Class.new(Additionals::TestIssueQueryChart) { def open_only_label = :label_issue_plural }
                 .new project: @project, settings: { group_by: 'tracker', open_only: '1' }

    with_settings display_subprojects_issues: '0' do
      assert_no_match(/projects\./, chart.send(:default_filters_statement))
    end
  end

  def test_url_of_open_only_keeps_values_the_query_does_not_exclude
    query = project_query 'status' => { operator: '!', values: %w[5] }

    assert_equal ['1'], url_values(project_chart_url(query), 'status')
  end

  def test_url_of_open_only_keeps_the_default_filter_for_any_value
    query = project_query 'status' => { operator: '*', values: [''] }

    assert_equal ['1'], url_values(project_chart_url(query), 'status')
  end

  def test_url_of_open_only_removes_excluded_values_of_a_default_filter
    query = project_query 'status' => { operator: '=', values: %w[1 5] }

    assert_equal ['1'], url_values(project_chart_url(query, excluding_default: true), 'status')
  end

  def test_url_of_open_only_joins_two_exclusions
    query = project_query 'status' => { operator: '!', values: %w[9] }

    assert_equal %w[5 9], url_values(project_chart_url(query, excluding_default: true), 'status').sort
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

  def test_group_options_do_not_contain_free_text
    assert_not_includes group_names(issue_chart), 'subject'
  end

  # The values of an issue field belong to the issue, not to its time entries
  def test_group_options_of_time_entries_do_not_contain_fields_of_the_issue
    field = multiple_list_field
    chart = Class.new(Additionals::TestIssueQueryChart) { def query_class = TimeEntryQuery }.new project: @project

    assert_not_includes group_names(chart), "issue.cf_#{field.id}"
  end

  def test_described_queries_contain_a_saved_query_with_description
    query = IssueQuery.create! name: 'Bugs', description: 'Bugs of the team', user: users(:users_001),
                               visibility: Query::VISIBILITY_PUBLIC

    assert_equal [query], issue_chart(group_by: 'tracker', query_id: query.id.to_s).described_queries
  end

  def test_described_queries_skip_a_query_without_description
    query = IssueQuery.create! name: 'Bugs', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC

    assert_empty issue_chart(group_by: 'tracker', query_id: query.id.to_s).described_queries
  end

  def test_described_queries_contain_the_compared_query
    query = IssueQuery.create! name: 'Last year', description: 'Created last year', user: users(:users_001),
                               visibility: Query::VISIBILITY_PUBLIC
    chart = issue_chart group_by: 'tracker', compare_query_id: query.id.to_s, chart_type: 'bar_vertical'

    assert_equal [query], chart.described_queries
  end

  def test_icon_follows_the_display_type
    assert_equal 'chart-line', issue_chart(group_by: 'start_date', chart_type: 'line').icon
  end

  def test_icon_of_bars
    assert_equal 'chart-bar', issue_chart(group_by: 'tracker', chart_type: 'bar_horizontal').icon
  end

  def test_default_measure_sums_up_a_column
    chart = Class.new(Additionals::TestIssueQueryChart) { def default_measure = 'estimated_hours' }
                 .new project: @project, settings: { group_by: 'tracker' }

    assert_equal :estimated_hours, chart.measure_column.name
  end

  def test_chosen_count_replaces_the_default_measure
    chart = Class.new(Additionals::TestIssueQueryChart) { def default_measure = 'estimated_hours' }
                 .new project: @project, settings: { group_by: 'tracker', measure: 'count' }

    assert_nil chart.measure_column
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
    assert_empty issue_chart(group_by: 'subject').entries
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

  def project_query(filters)
    ProjectQuery.create! name: 'Status', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC, filters:
  end

  # The link of the first slice with open only; excluding_default makes the
  # default filter "status is not closed" instead of "status is active"
  def project_chart_url(query, excluding_default: false)
    klass = excluding_default ? excluding_default_project_chart : Additionals::TestProjectQueryChart
    klass.new(project: nil, settings: { group_by: 'is_public', query_id: query.id.to_s, open_only: '1' }).entries.first.url
  end

  def excluding_default_project_chart
    Class.new Additionals::TestProjectQueryChart do
      private

      def default_filters
        { 'status' => { operator: '!', values: [Project::STATUS_CLOSED.to_s] } }
      end
    end
  end

  def project_chart(**settings)
    Additionals::TestProjectQueryChart.new project: nil, settings:
  end

  def url_values(url, field)
    Rack::Utils.parse_nested_query(URI(url).query)['v'][field]
  end

  def smallest_share(entries)
    entries.map(&:value).min * 100.0 / entries.sum(&:value)
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
