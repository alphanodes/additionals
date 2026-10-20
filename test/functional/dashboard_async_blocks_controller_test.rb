# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardAsyncBlocksControllerTest < Additionals::ControllerTest
  include Redmine::I18n

  def setup
    prepare_tests
    Setting.default_language = 'en'

    @project = projects :projects_001
    @welcome_dashboard = dashboards :system_default_welcome
    @project_dashboard = dashboards :system_default_project
  end

  def test_query_blocks
    assert_dashboard_query_blocks [
      { dashboard_id: @welcome_dashboard.id, block: 'issuequery', entities_class: 'issues' },
      { dashboard_id: @project_dashboard.id, block: 'issuequery', project: @project, entities_class: 'issues' }
    ]
  end

  # A private dashboard of another user is no error of a block
  def test_block_of_an_invisible_dashboard_is_forbidden
    @request.session[:user_id] = 3
    @request.headers['X-Requested-With'] = 'XMLHttpRequest'

    get :show, params: { dashboard_id: dashboards(:private_welcome2).id, block: 'legacy_left' }

    assert_response :forbidden
  end

  # A saved query whose SQL fails, e.g. with a filter of a plugin that is not
  # installed, is named as such
  def test_block_with_a_broken_query_names_the_query_error
    request_broken_query_block

    assert_select 'p#errorExplanation', text: l(:error_query_statement_invalid)
  end

  # Like the content, so the icons of the block stay next to the heading
  def test_block_error_has_the_heading_of_the_block
    request_broken_query_block

    assert_select 'h3 + p#errorExplanation'
  end

  # E.g. a private query of another user, the block still names itself
  def test_query_list_block_with_a_query_the_user_cannot_see_has_its_heading
    query = IssueQuery.create! name: 'Private', user: users(:users_002), visibility: Query::VISIBILITY_PRIVATE
    request_query_block query

    assert_select 'h3 + p.nodata'
  end

  # Stored before own columns, with a column removed since
  def test_query_list_block_with_settings_of_before_shows_its_list
    request_query_block queries(:queries_004), columns: %w[subject cf_999]

    assert_select 'h3.query-list-block'
  end

  private

  def request_broken_query_block
    query = IssueQuery.new name: 'Broken', user: users(:users_001), visibility: Query::VISIBILITY_PUBLIC,
                           filters: { 'missing_column' => { operator: '=', values: ['1'] } }
    query.save! validate: false
    request_query_block query
  end

  def request_query_block(query, **settings)
    dashboard = Dashboard.create! name: 'Broken query', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  author: users(:users_001), visibility: Dashboard::VISIBILITY_PUBLIC,
                                  layout: { 'top' => %w[issuequery] },
                                  layout_settings: { 'issuequery' => { query_id: query.id.to_s, **settings } }
    @request.session[:user_id] = 1
    # As the frontend requests a block
    @request.headers['Accept'] = 'text/html'
    @request.headers['X-Requested-With'] = 'XMLHttpRequest'

    get :show, params: { dashboard_id: dashboard.id, block: 'issuequery' }
  end
end
