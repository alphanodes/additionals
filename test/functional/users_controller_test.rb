# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ViewUsersShowContextualRenderOn < Redmine::Hook::ViewListener
  render_on :view_users_show_contextual, inline: '<div class="test">Example text</div>'
end

class ViewUsersShowInfoRenderOn < Redmine::Hook::ViewListener
  render_on :view_users_show_info, inline: '<div class="test">Example text</div>'
end

class UsersControllerTest < Additionals::ControllerTest
  fixtures :users, :groups_users, :email_addresses, :user_preferences,
           :roles, :members, :member_roles,
           :issues, :issue_statuses, :issue_relations,
           :issues, :issue_statuses, :issue_categories,
           :versions, :trackers,
           :projects, :projects_trackers, :enabled_modules,
           :enumerations

  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_show_with_hook_view_users_show_contextual
    Redmine::Hook.add_listener ViewUsersShowContextualRenderOn
    @request.session[:user_id] = 4
    get :show,
        params: { id: 2 }

    assert_response :success
    assert_select 'div.test', text: 'Example text'
  end

  def test_show_with_hook_view_users_show_info
    Redmine::Hook.add_listener ViewUsersShowInfoRenderOn
    @request.session[:user_id] = 4
    get :show,
        params: { id: 2 }

    assert_response :success
    assert_select 'div.test', text: 'Example text'
  end

  def test_show_new_issue_on_profile
    with_additionals_settings new_issue_on_profile: 1 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }

      assert_response :success
      assert_select 'a.user-new-issue'
    end
  end

  def test_not_show_new_issue_on_profile_without_activated
    with_additionals_settings new_issue_on_profile: 0 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }

      assert_response :success
      assert_select 'a.user-new-issue', count: 0
    end
  end
end
