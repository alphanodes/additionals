# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The assertions in global_test_helper.rb are used by every plugin of the family,
# so their own contract is tested here rather than in one of the plugins.
class GlobalTestHelperTest < Additionals::TestCase
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

  # The locale check reads source files with regular expressions and YAML files
  # by hand. Both are easy to break in a way that makes it quietly stop finding
  # anything - it would still pass, just without looking at the code any more.

  def test_finds_keys_in_every_supported_call_style
    keys = locale_keys_in_source <<~SOURCE
      l :label_symbol
      l(:label_parens)
      l 'label_single_quoted'
      l "label_double_quoted"
      I18n.t :label_i18n
      flash_msg :notice_own_key
      svg_icon_tag 'list', label: :label_deferred
      checklist << [:text_array_literal, value]
    SOURCE

    assert_equal %w[label_symbol label_parens label_single_quoted label_double_quoted
                    label_i18n notice_own_key label_deferred text_array_literal].to_set,
                 keys
  end

  def test_keeps_capitals_in_keys
    assert_equal Set['general_text_Yes'], locale_keys_in_source('l :general_text_Yes')
  end

  # flash_msg turns these five into keys of its own (notice_successful_create,
  # ...), every other symbol it gets is the key itself.
  def test_ignores_the_flash_msg_action_names
    assert_empty locale_keys_in_source("flash_msg :create\nflash_msg :save_error\n")
  end

  def test_ignores_commented_out_lines
    assert_empty locale_keys_in_source(<<~SOURCE)
      # l :label_ruby_comment
      / l :label_slim_comment
      <%# l :label_erb_comment %>
    SOURCE
  end

  # I18n.t :format, scope: 'number.currency' asks for number.currency.format -
  # a path this check cannot rebuild, so the line is left alone entirely.
  def test_ignores_lines_carrying_a_scope_argument
    assert_empty locale_keys_in_source("l :action_conflict, scope: 'activerecord.errors.messages'")
  end

  # title: is ActiveRecord ordering as often as it is a deferred translation,
  # so the deferred form only counts with an underscore in the key.
  def test_does_not_mistake_ordering_for_a_deferred_translation
    assert_empty locale_keys_in_source('scope.reorder title: :asc')
  end

  def test_locale_keys_include_intermediate_nodes_and_activerecord_bare_names
    keys = locale_keys_of fixture_locale_file(<<~YAML)
      en:
        label_flat: Flat
        seconds:
          one: second
          other: seconds
        activerecord:
          errors:
            messages:
              action_conflict: conflicts
    YAML

    # `l :seconds` addresses the pluralisation block itself
    assert_includes keys, 'seconds'
    assert_includes keys, 'seconds.one'
    assert_includes keys, 'label_flat'
    # reached as l :action_conflict, scope: 'activerecord.errors.messages'
    assert_includes keys, 'action_conflict'
    assert_includes keys, 'activerecord.errors.messages.action_conflict'
  end

  def test_locale_keys_of_a_missing_file_are_empty
    assert_empty locale_keys_of Rails.root.join('config/locales/does_not_exist.yml')
  end

  # Redmine core is the fallback for every plugin, so a broken core read would
  # flood the check with false positives instead of failing outright.
  def test_locale_keys_read_redmine_core
    assert_includes locale_keys_of(Rails.root.join('config/locales/en.yml')), 'label_issue'
  end

  # redmine_automation loads these directories out of every plugin, so code
  # there runs only when redmine_automation is installed.
  def test_automation_directories_are_excluded_from_the_scan
    assert automation_owned?('lib/automation_rules/my_rule.rb')
    assert_not automation_owned?('lib/redmine_ai/automation_rules_helper.rb')
    assert_not automation_owned?('app/models/automation_rules.rb')
  end

  def test_required_plugins_are_resolved_transitively
    assert_includes required_plugin_ids('additionals'), 'additionals'
  end

  private

  def fixture_locale_file(content)
    file = Tempfile.new %w[locale .yml]
    file.write content
    file.close
    @locale_files ||= []
    @locale_files << file
    file.path
  end
end
