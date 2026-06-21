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
  def setup
    Setting.default_language = 'en'
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

  def test_empty_full_width_group_skipped_on_locked_dashboard
    # system_default_welcome is locked (not sortable) and has no bottom blocks:
    # the empty full-width bottom receiver must be skipped (GitHub #112), while
    # the populated top and column groups stay present.
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div#list-top'
    assert_select 'div#list-left'
    assert_select 'div#list-bottom', count: 0
  end

  def test_empty_column_groups_skipped_when_both_empty_on_locked_dashboard
    # top_only_welcome is locked and has content only in the top group: with both
    # 50% columns empty there is no sibling to stretch, so left/right (and the
    # empty bottom) are skipped while the populated top stays present (GitHub #112).
    @request.session[:user_id] = 4
    get :index, params: { dashboard_id: dashboards(:top_only_welcome) }

    assert_response :success
    assert_select 'div#list-top'
    assert_select 'div#list-left', count: 0
    assert_select 'div#list-right', count: 0
    assert_select 'div#list-bottom', count: 0
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
    skip 'not tested if hrm is active' if AdditionalsPlugin.active_hrm?

    with_plugin_settings 'additionals', remove_help: 0 do
      @request.session[:user_id] = 1
      get :index

      # Redmine 6.x uses div#top-menu, Redmine master uses nav.top-menu
      assert_select '#top-menu a.help, nav.top-menu a.help'
    end
  end

  def test_show_index_without_help_menu
    skip 'not tested if hrm is active' if AdditionalsPlugin.active_hrm?

    with_plugin_settings 'additionals', remove_help: 1 do
      @request.session[:user_id] = 1
      get :index

      # Redmine 6.x uses div#top-menu, Redmine master uses nav.top-menu
      assert_select '#top-menu a.help, nav.top-menu a.help', count: 0
    end
  end

  def test_index_with_invalid_dashboard
    get :index,
        params: { dashboard_id: 444 }

    assert_response :missing
  end

  def test_index_with_public_project_dashboard
    get :index,
        params: { dashboard_id: dashboards(:public_project) }

    assert_response :missing
  end
end
