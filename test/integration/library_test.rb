# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class JavascriptLibraryTest < Additionals::IntegrationTest
  def test_not_loaded_chart_css_library
    skip 'not tested if reporting is active' if AdditionalsPlugin.active_reporting?

    log_user 'admin', 'admin'
    get '/'

    assert_response :success
    assert_select "head link:match('href',?)", %r{/Chart\.min}, count: 0
  end

  def test_not_loaded_chart_js_library
    skip 'not tested if reporting is active' if AdditionalsPlugin.active_reporting?

    log_user 'admin', 'admin'
    get '/'

    assert_response :success
    assert_select "script:match('src',?)", %r{/Chart\.bundle\.min.*\.js}, count: 0
  end

  def test_not_loaded_javascript_libraries
    log_user 'admin', 'admin'
    get '/'

    assert_response :success
    assert_select "script:match('src',?)", %r{/bootstrap.*\.js}, count: 0
    assert_select "script:match('src',?)", %r{/bootstrap\.min.*\.js}, count: 0
    assert_select "script:match('src',?)", %r{/d3plus.full\.min.*\.js}, count: 0
    assert_select "script:match('src',?)", %r{/mermaid_load.*\.js}, count: 0
    assert_select "script:match('src',?)", %r{/mermaid\.min.*\.js}, count: 0
  end

  # Redmine core renders mermaid code blocks itself with a library that has to
  # be installed separately. It loads the bundled one of additionals instead.
  def test_points_core_mermaid_rendering_at_the_bundled_library
    skip 'Redmine core renders no mermaid code blocks' unless defined? Redmine::Mermaid

    log_user 'admin', 'admin'
    get '/'

    assert_select 'head script', text: %r{window\.MermaidAssetUrl = ".*/plugin_assets/additionals/vendor/mermaid\.min.*\.js"}
  end

  def test_sets_no_mermaid_library_url_without_core_mermaid_rendering
    skip 'Redmine core renders mermaid code blocks' if defined? Redmine::Mermaid

    log_user 'admin', 'admin'
    get '/'

    assert_select 'head script', text: /MermaidAssetUrl/, count: 0
  end
end
