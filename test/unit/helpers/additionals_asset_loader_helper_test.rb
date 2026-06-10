# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsAssetLoaderHelperTest < Additionals::HelperTest
  include AdditionalsAssetLoaderHelper

  def test_emits_javascript_include_tag_for_js_package
    html = additionals_library_load :d3plus

    assert_match(/<script\b/, html)
    assert_match(/src=.+d3plus.min/, html)
    assert_match %r{/plugin_assets/additionals/}, html
  end

  def test_emits_stylesheet_link_tag_for_css_package
    html = additionals_library_load :font_awesome

    assert_match(/<link\b/, html)
    assert_match(/rel="stylesheet"/, html)
    assert_match(/href=.+fontawesome-all.min/, html)
  end

  def test_emits_both_css_and_js_for_dhtmlxgantt
    html = additionals_library_load :dhtmlxgantt

    assert_match(/<link\b/, html)
    assert_match(/href=.+dhtmlxgantt/, html)
    assert_match(/<script\b/, html)
    assert_match(/src=.+dhtmlxgantt/, html)
  end

  def test_chartjs_meta_emits_core_and_three_plugins
    html = additionals_library_load :chartjs_meta

    assert_match(/src=.+chart\.umd/, html)
    assert_match(/src=.+chartjs-plugin-colorschemes/, html)
    assert_match(/src=.+chartjs-plugin-datalabels/, html)
    assert_match(/src=.+chartjs-plugin-annotation/, html)
  end

  def test_accepts_array_and_concatenates_packages
    html = additionals_library_load %i[d3plus sortable]

    assert_match(/src=.+d3plus/, html)
    assert_match(/src=.+sortable\.min/, html)
  end

  def test_deduplicates_within_a_single_call_via_registry
    # chartjs_meta already pulls in chartjs's colorschemes; an explicit
    # chartjs_colorschemes alongside should not produce a second tag.
    html = additionals_library_load %i[chartjs_meta chartjs_colorschemes]
    occurrences = html.scan('chartjs-plugin-colorschemes').size

    assert_equal 1, occurrences
  end

  def test_deduplicates_across_calls_within_same_request
    first = additionals_library_load :d3plus
    second = additionals_library_load :d3plus

    assert_match(/src=.+d3plus/, first)
    assert_equal '', second.to_s
  end

  def test_omits_plugin_param_for_core_assets
    html = additionals_library_load :actioncable

    # core assets resolve to Redmine core JS, not to plugin_assets/additionals
    assert_match(/src=.+actioncable/, html)
    assert_no_match %r{/plugin_assets/additionals/actioncable}, html
  end

  def test_returns_html_safe_string
    html = additionals_library_load :d3plus

    assert_predicate html, :html_safe?
  end
end
