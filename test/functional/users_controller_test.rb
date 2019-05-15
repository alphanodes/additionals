require File.expand_path('../../test_helper', __FILE__)

class UsersControllerTest < Additionals::ControllerTest
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
           :enabled_modules

  include Redmine::I18n

  def setup
    prepare_tests
    @controller = UsersController.new
    User.current = nil
  end

  def test_show_new_issue_on_profile
    with_additionals_settings(new_issue_on_profile: 1) do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }
      assert_select 'a.user-new-issue'
    end
  end

  def test_not_show_new_issue_on_profile_without_activated
    with_additionals_settings(new_issue_on_profile: 0) do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }
      assert_select 'a.user-new-issue', count: 0
    end
  end
end
