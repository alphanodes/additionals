# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Validates that all Deface overrides from additionals have correct hashes.
# This ensures the overrides still match their target elements in Redmine templates.
#
# Overrides are identified as belonging to this plugin by their partial path
# containing 'additionals' or 'hooks/view_'.
#
class AdditionalsDefaceOverridesTest < Additionals::TestCase
  def test_all_deface_overrides_have_valid_hashes
    assert_deface_overrides_valid partial_patterns: %w[additionals hooks/view_]
  end
end
