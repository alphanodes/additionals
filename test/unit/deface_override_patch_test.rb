# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DefaceOverridePatchTest < Additionals::TestCase
  VIRTUAL_PATH = 'additionals_test/deface_patch'
  OVERRIDE_NAME = 'additionals-test-deface-patch'

  # A helper whose name contains the template name, as ai_wiki_edit_button_data does for
  # wiki/edit. Deface took it for a compiled template and failed to remove it.
  module HelperWithTemplateName
    def helper_additionals_test_deface_patch_data; end
  end

  def teardown
    # The template does not exist, a leftover override would fail the hash check of all overrides
    Deface::Override.all.delete VIRTUAL_PATH.to_sym
    template_class = Deface.template_class
    template_class.send :remove_method, compiled_name if template_class.method_defined? compiled_name, false
    super
  end

  def test_a_helper_named_like_the_template_does_not_break_the_override
    Deface.template_class.include HelperWithTemplateName

    assert_nothing_raised { create_override }
  end

  def test_an_outdated_compiled_template_is_still_removed
    Deface.template_class.define_method(compiled_name) { nil }

    create_override

    assert_not Deface.template_class.method_defined?(compiled_name)
  end

  private

  def compiled_name
    :_additionals_test_deface_patch_html_erb__1_2
  end

  def create_override
    Deface::Override.new virtual_path: VIRTUAL_PATH, name: OVERRIDE_NAME, insert_before: 'p', text: ''
  end
end
