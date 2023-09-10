# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsMacroTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issue_categories, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def setup
    prepare_tests

    @all_macros = Redmine::WikiFormatting::Macros.available_macros.map { |macro, _macro_options| macro.to_s }
  end

  def test_all
    available_macros = AdditionalsMacro.macros

    assert_not_equal 0, available_macros.count
  end

  def test_all_with_only_names
    available_macros = AdditionalsMacro.macros only_names: true

    assert_includes available_macros, 'child_pages'
  end

  def test_with_filter
    available_macros = AdditionalsMacro.macros filtered: ['child_pages'], only_names: true

    assert_not_includes available_macros, 'child_pages'

    for_two_macros_selection = @all_macros - %w[child_pages collapse] + ['', 'nonexistingmacro']
    available_macros = AdditionalsMacro.macros filtered: for_two_macros_selection, only_names: true

    # -1 (hello world is always removed)
    assert_equal %w[child_pages collapse], available_macros
  end

  def test_with_filter_all
    available_macros = AdditionalsMacro.macros filtered: @all_macros, only_names: true

    assert_equal 0, available_macros.count
  end

  def test_with_controller_limit
    available_macros = AdditionalsMacro.macros only_names: true, controller_only: 'issue'

    assert_not_includes available_macros, 'child_pages'

    available_macros = AdditionalsMacro.macros only_names: true, controller_only: 'wiki'

    assert_includes available_macros, 'child_pages'
  end
end
