require File.expand_path('../../test_helper', __FILE__)

class AccountControllerTest < ActionController::TestCase
  fixtures :users, :email_addresses, :roles

  def setup
    Setting.default_language = 'en'
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end

  def test_get_login_with_welcome_text
    Setting.plugin_additionals = ActionController::Parameters.new(
      account_login_bottom: 'Lore impsuum'
    )
    get :login
    assert_response :success
    assert_template 'login'

    assert_select 'input[name=username]'
    assert_select 'input[name=password]'
    assert_select 'div.login-additionals', text: /Lore impsuum/
  end

  def test_get_login_without_welcome_text
    Setting.plugin_additionals = ActionController::Parameters.new(
      account_login_bottom: ''
    )

    get :login
    assert_response :success
    assert_template 'login'

    assert_select 'input[name=username]'
    assert_select 'input[name=password]'
    assert_select 'div.login-additionals', count: 0
  end
end
