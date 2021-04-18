# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ViewDashboardTopRenderOn < Redmine::Hook::ViewListener
  render_on :view_dashboard_top, inline: '<div class="test">Example text</div>'
end

class ViewDashboardBottomRenderOn < Redmine::Hook::ViewListener
  render_on :view_dashboard_bottom, inline: '<div class="test">Example text</div>'
end

class ProjectsControllerTest < Additionals::ControllerTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :dashboards, :dashboard_roles

  def setup
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_show_with_left_text_block
    @request.session[:user_id] = 4
    get :show,
        params: { id: 1 }

    assert_response :success
    assert_select 'div#list-left div#block-text', text: /example text/
  end

  def test_show_with_right_text_block
    @request.session[:user_id] = 4
    get :show,
        params: { id: 1 }

    assert_response :success
    assert_select 'div#list-right div#block-text__1', text: /example text/
  end

  def test_show_with_hook_view_dashboard_top
    Redmine::Hook.add_listener ViewDashboardTopRenderOn
    @request.session[:user_id] = 4
    get :show,
        params: { id: 1 }

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_hook_view_dashboard_bottom
    Redmine::Hook.add_listener ViewDashboardBottomRenderOn
    @request.session[:user_id] = 4
    get :show,
        params: { id: 1 }

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_invalid_dashboard
    get :show,
        params: { id: 1,
                  dashboard_id: 444 }

    assert_response :missing
  end

  def test_show_dashboard_without_permission
    @request.session[:user_id] = 3

    get :show,
        params: { id: 1,
                  dashboard_id: dashboards(:private_project2) }

    assert_response :forbidden
  end
end
