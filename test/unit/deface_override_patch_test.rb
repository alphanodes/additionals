# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DefaceOverridePatchTest < Additionals::TestCase
  VIRTUAL_PATH = 'additionals_test/deface_patch'
  OVERRIDE_NAME = 'additionals-test-deface-patch'
  COMPILED_NAME = :_plugins_additionals_app_views_additionals_test_deface_patch_html_erb___123_456

  # Global helpers whose names contain the template path. Deface took them for a compiled
  # template and failed to remove them.
  module HelperWithTemplateName
    def foo_additionals_test_deface_patch_data; end

    def _additionals_test_deface_patch_path; end
  end

  def setup
    super
    # A separate view class keeps the test methods out of the real Deface template class
    @template_class = Class.new ActionDispatch::DebugView
    @template_class.include HelperWithTemplateName
    Deface.stubs(:template_class).returns @template_class
  end

  def teardown
    # The template does not exist, a leftover override would fail the hash check of all overrides
    Deface::Override.all.delete VIRTUAL_PATH.to_sym
    super
  end

  def test_a_helper_named_like_the_template_does_not_break_the_override
    assert_nothing_raised { create_override }
  end

  def test_a_helper_with_leading_underscore_named_like_the_template_is_kept
    create_override

    assert @template_class.method_defined?(:_additionals_test_deface_patch_path)
  end

  def test_an_outdated_compiled_template_is_still_removed
    @template_class.define_method(COMPILED_NAME) { nil }

    create_override

    assert_not @template_class.method_defined?(COMPILED_NAME)
  end

  private

  def create_override
    Deface::Override.new virtual_path: VIRTUAL_PATH, name: OVERRIDE_NAME, insert_before: 'p', text: ''
  end
end
