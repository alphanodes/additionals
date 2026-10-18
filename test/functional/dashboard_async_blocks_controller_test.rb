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
end
