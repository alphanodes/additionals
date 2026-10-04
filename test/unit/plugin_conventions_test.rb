# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Conventions that hold for the plugin as a whole. Each of them breaks in a way
# no feature test would notice - a locale that lost a key, a patch that reaches
# nothing, a Deface anchor that moved - so they are collected here instead of
# hiding in the test of whatever code happens to be affected.
class PluginConventionsTest < Additionals::TestCase
  Additionals.define_i18n_tests self,
                                plugin: 'additionals',
                                control_string: :label_open_external_urls,
                                control_english: 'Open external URLs',
                                # the hrm user type filter is only added when redmine_hrm
                                # patches the query - checked, it never renders without it;
                                # label_users_and_groups comes with Redmine 7.1 and is only
                                # rendered when core supports groups in user fields (https://www.redmine.org/issues/21026);
                                # TODO(Redmine 7.0 EOL): remove label_users_and_groups here
                                allowed_missing: %i[field_hrm_user_type label_users_and_groups]

  def setup
    prepare_tests
  end

  # A patch that no add_patch names, or whose target class was renamed, simply
  # does nothing - and every other test still passes. This is the only place that
  # notices.
  def test_every_patch_reaches_a_class
    assert_plugin_patches_applied Additionals
  end

  # Overrides belong to this plugin by the prefix of their name, so overrides
  # built from :text are covered as well. A hash mismatch does not break the
  # page - Deface logs it and applies the override anyway - so a moved anchor
  # is noticed nowhere else.
  def test_all_deface_overrides_have_valid_hashes
    assert_deface_overrides_valid name_prefix: 'additionals'
  end
end
