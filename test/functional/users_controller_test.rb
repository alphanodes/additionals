require File.expand_path('../test_helper', __dir__)

class UsersControllerTest < Redmine::ControllerTest
  fixtures :projects,
           :users,
           :email_addresses

  include Redmine::I18n

  def setup
    Additionals::TestCase.prepare
    @controller = UsersController.new
    User.current = nil
  end

  def test_show_new_issue_on_profile
    Setting.plugin_additionals = ActionController::Parameters.new(
      new_issue_on_profile: 1
    )

    @request.session[:user_id] = 2
    get :show, id: 2
    assert_select 'a.user-new-issue'
  end

  def test_not_show_new_issue_on_profile_without_activated
    Setting.plugin_additionals = ActionController::Parameters.new(
      new_issue_on_profile: 0
    )

    @request.session[:user_id] = 2
    get :show, id: 2
    assert_select 'a.user-new-issue', count: 0
  end
end
