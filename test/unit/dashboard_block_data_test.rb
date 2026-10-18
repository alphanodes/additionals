# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The data a block shows and what programs read of it
class DashboardBlockDataTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_001
    @project = projects :projects_001
  end

  def test_news_exclude_subprojects_by_default
    news = create_subproject_news

    assert_not_includes block('news', {}, @project).data, news
  end

  def test_news_include_subprojects_if_chosen
    news = create_subproject_news

    assert_includes block('news', { with_subprojects: '1' }, @project).data, news
  end

  def test_news_are_limited_to_max_entries
    assert_equal 1, block('news', { max_entries: '1' }).data.size
  end

  def test_news_export_their_titles
    assert_equal News.latest(User.current, 2).map(&:title), block('news', { max_entries: '2' }).export_data.pluck(:title)
  end

  def test_documents_of_the_project_only
    assert_empty(block('documents', {}, @project).data.reject { |document| document.project == @project })
  end

  def test_spent_time_sums_the_hours_of_the_user
    TimeEntry.generate! user: User.current, project: @project, spent_on: User.current.today, hours: 2.5

    assert_in_delta 2.5, block('my_spent_time', {}, @project).data[:today_hours]
  end

  def test_activity_of_the_user_only
    events = block('activity', { me_only: '1' }).data.values.flatten

    assert_empty(events.reject { |event| event.event_author == User.current })
  end

  def test_feed_without_url_is_not_valid
    assert_not block('feed').data[:valid]
  end

  def test_text_exports_title_and_text
    assert_equal({ title: 'Hello', text: 'Some *text*' }, block('text', { title: 'Hello', text: 'Some *text*' }).export_data)
  end

  def test_query_list_lists_the_entries_of_its_query
    list = block('issuequery', { query_id: queries(:queries_004).id.to_s }).data

    assert_equal list[:query].issue_count, list[:count]
  end

  def test_query_list_without_visible_query_has_no_data
    assert_nil block('issuequery', { query_id: '999999' }).data
  end

  def test_query_list_exports_a_value_per_column
    query = IssueQuery.create! name: 'All issues', visibility: Query::VISIBILITY_PUBLIC, user: User.current,
                               filters: { 'status_id' => { operator: '*', values: [''] } }
    data = block('issuequery', { query_id: query.id.to_s, max_entries: '2' }).export_data

    assert_equal [data[:columns].size] * 2, data[:rows].map(&:size)
  end

  # Like the list, issues show their id first
  def test_query_list_exports_the_chosen_columns
    data = block('issuequery', { query_id: queries(:queries_004).id.to_s, columns: %w[tracker subject] }).export_data

    assert_equal [I18n.t(:field_tracker), I18n.t(:field_subject)], data[:columns].last(2)
  end

  def test_export_names_typed_settings
    assert_equal({ max_entries: 3, with_subprojects: false }, block('news', { max_entries: '3' }, @project).export[:settings])
  end

  def test_export_names_only_settings_of_the_context
    assert_equal({ max_entries: 3 }, block('news', { max_entries: '3' }).export[:settings])
  end

  def test_block_without_data_exports_none
    assert_nil block('welcome').export[:data]
  end

  def test_dashboard_exports_a_block_of_its_layout
    dashboard = welcome_dashboard layout_settings: { 'text' => { title: 'Hello', text: 'World' } }

    assert_equal 'World', dashboard.block_export('text')[:data][:text]
  end

  # The layout of a dashboard for programs, without loading the data of every block
  def test_dashboard_exports_a_block_without_its_data
    dashboard = welcome_dashboard layout_settings: { 'text' => { title: 'Hello', text: 'World' } }

    assert_equal({ block: 'text', label: I18n.t(:label_text_sync), settings: { title: 'Hello', text: 'World' } },
                 dashboard.block_export('text', data: false))
  end

  def test_dashboard_exports_no_block_outside_its_layout
    assert_nil welcome_dashboard.block_export('news')
  end

  def test_available_blocks_tell_whether_they_export_data
    schemas = DashboardContentWelcome.new.available_block_schemas

    assert_equal [true, false], [schemas['text'][:exports_data], schemas['welcome'][:exports_data]]
  end

  private

  # A block with its stored settings, on a project dashboard with a project
  def block(id, settings = {}, project = nil)
    content = project ? DashboardContentProject.new(project:) : DashboardContentWelcome.new
    content.dashboard_block id, settings:
  end

  def welcome_dashboard(layout_settings: {})
    Dashboard.new name: 'Export', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current,
                  layout: { 'left' => %w[text] }, layout_settings:
  end

  def create_subproject_news
    subproject = projects :projects_003
    subproject.enable_module! :news
    News.create! project: subproject, title: 'Subproject news', description: 'News from a subproject', author: User.current
  end
end
