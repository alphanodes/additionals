# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ViewWelcomeIndexTopRenderOn < Redmine::Hook::ViewListener
  render_on :view_welcome_index_top, inline: '<div class="test">Example text</div>'
end

class ViewWelcomeIndexBottomRenderOn < Redmine::Hook::ViewListener
  render_on :view_welcome_index_bottom, inline: '<div class="test">Example text</div>'
end

class ViewDashboardTopRenderOn < Redmine::Hook::ViewListener
  render_on :view_dashboard_top, inline: '<div class="test">Example text</div>'
end

class ViewDashboardBottomRenderOn < Redmine::Hook::ViewListener
  render_on :view_dashboard_bottom, inline: '<div class="test">Example text</div>'
end

class WelcomeControllerTest < Additionals::ControllerTest
  fixtures :projects, :news, :users, :members,
           :dashboards, :dashboard_roles

  def setup
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_show_with_left_text_block
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div#list-left div#block-text', text: /example text/
  end

  def test_show_with_right_text_block
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div#list-right div#block-text__1', text: /example text/
  end

  def test_show_with_hook_view_welcome_index_top
    Redmine::Hook.add_listener ViewWelcomeIndexTopRenderOn
    @request.session[:user_id] = 4
    get :index

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_hook_view_welcome_index_bottom
    Redmine::Hook.add_listener ViewWelcomeIndexBottomRenderOn
    @request.session[:user_id] = 4
    get :index

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_hook_view_dashboard_top
    Redmine::Hook.add_listener ViewDashboardTopRenderOn
    @request.session[:user_id] = 4
    get :index

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_hook_view_dashboard_bottom
    Redmine::Hook.add_listener ViewDashboardBottomRenderOn
    @request.session[:user_id] = 4
    get :index

    assert_select 'div.test', text: 'Example text'
  end

  def test_show_index_with_help_menu
    skip if Redmine::Plugin.installed? 'redmine_hrm'

    with_additionals_settings remove_help: 0 do
      @request.session[:user_id] = 1
      get :index

      assert_select 'div#top-menu a.help'
    end
  end

  def test_show_index_without_help_menu
    skip if Redmine::Plugin.installed? 'redmine_hrm'

    with_additionals_settings remove_help: 1 do
      @request.session[:user_id] = 1
      get :index

      assert_select 'div#top-menu a.help', count: 0
    end
  end

  def test_index_with_invalid_dashboard
    get :index,
        params: { dashboard_id: 444 }

    assert_response :missing
  end
end
