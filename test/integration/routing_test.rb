# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RoutingTest < Redmine::RoutingTest
  def test_issue_assign_to_me
    should_route 'PUT /issues/1/assign_to_me' => 'additionals_assign_to_me#update', issue_id: '1'
  end

  def test_issue_change_status
    should_route 'PUT /issues/1/change_status' => 'additionals_change_status#update', issue_id: '1'
  end

  def test_help_macro
    should_route 'GET /help/macros' => 'additionals_macros#show'
  end

  def test_auto_completes
    should_route 'GET /auto_completes/fontawesome' => 'auto_completes#fontawesome'
    should_route 'GET /auto_completes/issue_assignee' => 'auto_completes#issue_assignee'
    should_route 'GET /auto_completes/assignee' => 'auto_completes#assignee'
    should_route 'GET /auto_completes/authors' => 'auto_completes#authors'
    should_route 'GET /auto_completes/grouped_principals' => 'auto_completes#grouped_principals'
    should_route 'GET /auto_completes/grouped_users' => 'auto_completes#grouped_users'
    should_route 'GET /auto_completes/custom_field_users' => 'auto_completes#custom_field_users'
  end

  def test_global_search
    should_route 'GET /global_search/search' => 'global_search#search'
  end

  def test_dashboards
    should_route 'GET /dashboards.xml' => 'dashboards#index', format: 'xml'
    should_route 'GET /dashboards.json' => 'dashboards#index', format: 'json'

    should_route 'GET /dashboards/1.xml' => 'dashboards#show', id: '1', format: 'xml'
    should_route 'GET /dashboards/1.json' => 'dashboards#show', id: '1', format: 'json'
    should_route 'GET /dashboards/1/edit' => 'dashboards#edit', id: '1'

    should_route 'POST /dashboards/1/update_layout_setting' => 'dashboards#update_layout_setting', id: '1'
    should_route 'POST /dashboards/1/add_block' => 'dashboards#add_block', id: '1'
    should_route 'POST /dashboards/1/remove_block' => 'dashboards#remove_block', id: '1'
    should_route 'POST /dashboards/1/order_blocks' => 'dashboards#order_blocks', id: '1'
    should_route 'PUT /dashboards/1/lock' => 'dashboards#lock', id: '1'
    should_route 'PUT /dashboards/1/unlock' => 'dashboards#unlock', id: '1'

    should_route 'GET /projects/foo/dashboards.xml' => 'dashboards#index', project_id: 'foo', format: 'xml'
    should_route 'GET /projects/foo/dashboards.json' => 'dashboards#index', project_id: 'foo', format: 'json'

    should_route 'POST /projects/foo/dashboards/1/update_layout_setting' => 'dashboards#update_layout_setting',
                 project_id: 'foo', id: '1'
    should_route 'POST /projects/foo/dashboards/1/add_block' => 'dashboards#add_block', project_id: 'foo', id: '1'
    should_route 'POST /projects/foo/dashboards/1/remove_block' => 'dashboards#remove_block', project_id: 'foo', id: '1'
    should_route 'POST /projects/foo/dashboards/1/order_blocks' => 'dashboards#order_blocks', project_id: 'foo', id: '1'
    should_route 'PUT /projects/foo/dashboards/1/lock' => 'dashboards#lock', project_id: 'foo', id: '1'
    should_route 'PUT /projects/foo/dashboards/1/unlock' => 'dashboards#unlock', project_id: 'foo', id: '1'
  end

  def test_dashboard_async_blocks
    should_route 'GET /dashboard_async_blocks' => 'dashboard_async_blocks#show'
    should_route 'POST /dashboard_async_blocks' => 'dashboard_async_blocks#create'
    should_route 'GET /projects/foo/dashboard_async_blocks' => 'dashboard_async_blocks#show', project_id: 'foo'
    should_route 'POST /projects/foo/dashboard_async_blocks' => 'dashboard_async_blocks#create', project_id: 'foo'
  end
end
