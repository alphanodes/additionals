require File.expand_path('../../test_helper', __FILE__)

class JavascriptLibraryTest < Redmine::IntegrationTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers

  def test_loaded_css_libraries
    log_user('admin', 'admin')
    get '/'

    assert_response :success
    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/fontawesome-all.min.css'

    return unless Redmine::Plugin.installed?('redmine_reporting')

    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/Chart.min.css', count: 1
  end

  def test_not_loaded_css_libraries
    log_user('admin', 'admin')
    get '/'

    assert_response :success

    return if Redmine::Plugin.installed?('redmine_reporting')

    assert_select 'link[rel=stylesheet][href^=?]', '/plugin_assets/additionals/stylesheets/Chart.min.css', count: 0
  end

  def test_loaded_javascript_libraries
    log_user('admin', 'admin')
    get '/'

    return unless Redmine::Plugin.installed?('redmine_reporting')

    assert_response :success
    assert_select 'script[src^=?]', '/plugin_assets/additionals/javascripts/Chart.bundle.min.js', count: 1
  end

  def test_not_loaded_javascript_libraries
    log_user('admin', 'admin')
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
