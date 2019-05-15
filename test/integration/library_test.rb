require File.expand_path('../../test_helper', __FILE__)

class JavascriptLibraryTest < Redmine::IntegrationTest
  def test_loaded_css_libraries
    get '/'

    assert_response :success
    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/fontawesome-all.min.css'

    return unless Redmine::Plugin.installed?('redmine_reporting')

    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/nv.d3.min.css', count: 1
  end

  def test_not_loaded_css_libraries
    get '/'

    assert_response :success

    return if Redmine::Plugin.installed?('redmine_reporting')

    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/nv.d3.min.css', count: 0
  end

  def test_not_loaded_javascript_libraries
    get '/'

    assert_response :success
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/bootstrap.js', count: 0
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/bootstrap.min.js', count: 0
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/d3plus.full.min.js', count: 0
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/noreferrer.js', count: 0
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/mermaid.min.js', count: 0
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/mermaid_load.js', count: 0
  end
end
