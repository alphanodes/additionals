# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

require File.expand_path('../../test_helper', __FILE__)

class WelcomeControllerTest < ActionController::TestCase
  fixtures :projects, :news, :users, :members

  def setup
    Setting.default_language = 'en'
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end

  def test_show_with_overview_right
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_right: 'Lore impsuum'
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-right', text: /Lore impsuum/
  end

  def test_show_without_overview_right
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_right: ''
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-right', count: 0
  end

  def test_show_with_overview_bottom
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_bottom: 'Lore impsuum'
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-bottom', text: /Lore impsuum/
  end

  def test_show_without_overview_bottom
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_bottom: ''
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-bottom', count: 0
  end

  def test_show_with_overview_top
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_top: 'Lore impsuum'
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-top', text: /Lore impsuum/
  end

  def test_show_without_overview_top
    Setting.plugin_redmine_tweaks = ActionController::Parameters.new(
      overview_top: ''
    )
    @request.session[:user_id] = 4
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_select 'div.overview-top', count: 0
  end
end
