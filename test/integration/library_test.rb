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
end
