require File.expand_path('../../test_helper', __FILE__)

class WelcomeControllerTest < Additionals::ControllerTest
  fixtures :projects, :news, :users, :members

  def setup
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_show_with_overview_right
    with_additionals_settings(overview_right: 'Lore impsuum')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-right', text: /Lore impsuum/
  end

  def test_show_without_overview_right
    with_additionals_settings(overview_right: '')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-right', count: 0
  end

  def test_show_with_overview_bottom
    with_additionals_settings(overview_bottom: 'Lore impsuum')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-bottom', text: /Lore impsuum/
  end

  def test_show_without_overview_bottom
    with_additionals_settings(overview_bottom: '')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-bottom', count: 0
  end

  def test_show_with_overview_top
    with_additionals_settings(overview_top: 'Lore impsuum')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-top', text: /Lore impsuum/
  end

  def test_show_without_overview_top
    with_additionals_settings(overview_top: '')
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_select 'div.overview-top', count: 0
  end
end
