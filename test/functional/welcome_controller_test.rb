require File.expand_path('../../test_helper', __FILE__)

class WelcomeControllerTest < Additionals::ControllerTest
  fixtures :projects, :news, :users, :members

  def setup
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_show_with_overview_right
    with_additionals_settings(overview_right: 'Lore impsuum') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-right', text: /Lore impsuum/
    end
  end

  def test_show_without_overview_right
    with_additionals_settings(overview_right: '') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-right', count: 0
    end
  end

  def test_show_with_overview_bottom
    with_additionals_settings(overview_bottom: 'Lore impsuum') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-bottom', text: /Lore impsuum/
    end
  end

  def test_show_without_overview_bottom
    with_additionals_settings(overview_bottom: '') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-bottom', count: 0
    end
  end

  def test_show_with_overview_top
    with_additionals_settings(overview_top: 'Lore impsuum') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-top', text: /Lore impsuum/
    end
  end

  def test_show_without_overview_top
    with_additionals_settings(overview_top: '') do
      @request.session[:user_id] = 4
      get :index

      assert_response :success
      assert_select 'div.overview-top', count: 0
    end
  end

  def test_show_index_with_help_menu
    with_additionals_settings(remove_help: 0) do
      @request.session[:user_id] = 1
      get :index

      assert_select 'div#top-menu a.help'
    end
  end

  def test_show_index_without_help_menu
    with_additionals_settings(remove_help: 1) do
      @request.session[:user_id] = 1
      get :index

      assert_select 'div#top-menu a.help', count: 0
    end
  end
end
