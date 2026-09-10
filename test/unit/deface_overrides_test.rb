# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Validates that all Deface overrides from additionals still match their target elements
# in the templates they are anchored to.
#
# Overrides belong to this plugin by the prefix of their name, so overrides built from
# :text are covered as well.
#
class AdditionalsDefaceOverridesTest < Additionals::TestCase
  def test_all_deface_overrides_have_valid_hashes
    assert_deface_overrides_valid name_prefix: 'additionals'
  end

  # A plugin may override a template of an optional third party plugin. Where
  # that plugin is not installed the template is absent and the override never
  # applies - not a defect, so optional_templates lets the assertion pass. The
  # default must keep reporting it, because for a core template a missing
  # template is exactly the drift this assertion exists for.
  def test_missing_template_is_reported_by_default_and_skipped_when_optional
    Deface::Override.new virtual_path: 'not_here/_gone',
                         name: 'optionaltest-missing-template',
                         insert_bottom: 'div',
                         original: 'irrelevant',
                         text: '<span></span>'

    error = assert_raises Minitest::Assertion do
      assert_deface_overrides_valid name_prefix: 'optionaltest'
    end

    assert_includes error.message, 'template not found'

    # With the flag the missing template is skipped - and then no override of
    # that prefix remains, which the assertion reports as a wrong prefix.
    skipped = assert_raises Minitest::Assertion do
      assert_deface_overrides_valid name_prefix: 'optionaltest', optional_templates: true
    end

    assert_includes skipped.message, 'plugin prefix is probably wrong'
    assert_not_includes skipped.message, 'template not found'
  ensure
    Deface::Override.all['not_here/_gone']&.delete 'optionaltest-missing-template'
  end
end
