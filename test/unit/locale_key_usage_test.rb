# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The locale check reads source files with regular expressions and YAML files
# by hand. Both are easy to break in a way that makes it quietly stop finding
# anything - it would still pass, just without looking at the code any more.
class LocaleKeyUsageTest < Additionals::TestCase
  def test_finds_keys_in_every_supported_call_style
    keys = usage.locale_keys_in_source <<~SOURCE
      l :label_symbol
      l(:label_parens)
      l 'label_single_quoted'
      l "label_double_quoted"
      l 'activerecord.errors.messages.taken'
      I18n.t :label_i18n
      I18n.t('label_i18n_quoted')
      = t :label_view_helper
      = t('date.month_names')
      flash_msg :notice_own_key
      svg_icon_tag 'list', label: :label_deferred
      checklist << [:text_array_literal, value]
    SOURCE

    assert_equal %w[label_symbol label_parens label_single_quoted label_double_quoted
                    activerecord.errors.messages.taken label_i18n label_i18n_quoted label_view_helper
                    date.month_names notice_own_key label_deferred text_array_literal].to_set,
                 keys
  end

  def test_keeps_capitals_in_keys
    assert_equal Set['general_text_Yes'], usage.locale_keys_in_source('l :general_text_Yes')
  end

  # t('.key') is relative to the view, an interpolated key cannot be rebuilt,
  # and a method merely ending in t is no translation.
  def test_ignores_lazy_interpolated_and_lookalike_calls
    assert_empty usage.locale_keys_in_source(<<~SOURCE)
      = t('.title')
      l "label_\#{name}"
      format :csv
      object.t :label_receiver
      list.select { |entry| entry.split :label_split }
    SOURCE
  end

  # flash_msg turns these five into keys of its own (notice_successful_create,
  # ...), every other symbol it gets is the key itself.
  def test_ignores_the_flash_msg_action_names
    assert_empty usage.locale_keys_in_source("flash_msg :create\nflash_msg :save_error\n")
  end

  def test_ignores_commented_out_lines
    assert_empty usage.locale_keys_in_source(<<~SOURCE)
      # l :label_ruby_comment
      / l :label_slim_comment
      <%# l :label_erb_comment %>
    SOURCE
  end

  # I18n.t :format, scope: 'number.currency' asks for number.currency.format -
  # a path this check cannot rebuild, so the line is left alone entirely.
  def test_ignores_lines_carrying_a_scope_argument
    assert_empty usage.locale_keys_in_source("l :action_conflict, scope: 'activerecord.errors.messages'")
  end

  # title: is ActiveRecord ordering as often as it is a deferred translation,
  # so the deferred form only counts with an underscore in the key.
  def test_does_not_mistake_ordering_for_a_deferred_translation
    assert_empty usage.locale_keys_in_source('scope.reorder title: :asc')
  end

  # Menu captions live in init.rb
  def test_scans_init_rb
    directory = additionals_directory

    assert_includes usage.source_files(directory), File.join(directory, 'init.rb')
  end

  def test_used_locale_keys_name_the_files_relative_to_the_plugin
    used = usage.used_locale_keys additionals_directory

    assert_includes used['label_additionals'], 'init.rb'
  end

  def test_locale_keys_include_intermediate_nodes_and_activerecord_bare_names
    file = locale_file <<~YAML
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
    keys = usage.locale_keys_of file.path

    # `l :seconds` addresses the pluralisation block itself
    assert_includes keys, 'seconds'
    assert_includes keys, 'seconds.one'
    assert_includes keys, 'label_flat'
    # reached as l :action_conflict, scope: 'activerecord.errors.messages'
    assert_includes keys, 'action_conflict'
    assert_includes keys, 'activerecord.errors.messages.action_conflict'
  end

  def test_locale_keys_of_a_missing_file_are_empty
    assert_empty usage.locale_keys_of(Rails.root.join('config/locales/does_not_exist.yml').to_s)
  end

  # Redmine core and Rails are the fallback for every plugin, so a broken read
  # would flood the check with false positives instead of failing outright.
  def test_core_locale_keys_read_redmine_and_rails
    keys = usage.core_locale_keys Rails.root.to_s

    assert_includes keys, 'label_issue'
    # from activemodel, not from Redmine
    assert_includes keys, 'errors.format'
  end

  # redmine_automation loads these directories out of every plugin, so code
  # there runs only when redmine_automation is installed.
  def test_automation_directories
    assert usage.automation_owned?('lib/automation_rules/my_rule.rb')
    assert_not usage.automation_owned?('lib/my_plugin/automation_rules_helper.rb')
    assert_not usage.automation_owned?('app/models/automation_rules.rb')
  end

  def test_required_plugins_are_resolved_transitively
    assert_includes usage.required_plugin_ids(File.dirname(additionals_directory), 'additionals'), 'additionals'
  end

  private

  def usage
    Additionals::LocaleKeyUsage
  end

  def additionals_directory
    Redmine::Plugin.find(:additionals).directory
  end

  def locale_file(content)
    file = Tempfile.new %w[locale .yml]
    file.write content
    file.close
    file
  end
end
