# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RedmineAccessControlTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  def test_available_project_modules_all
    assert_kind_of Array, Redmine::AccessControl.available_project_modules_all
  end

  def test_disabled_project_modules
    assert_empty Redmine::AccessControl.disabled_project_modules

    with_plugin_settings 'additionals', disabled_modules: %i[news] do
      assert_equal [:news], Redmine::AccessControl.disabled_project_modules
    end

    assert_empty Redmine::AccessControl.disabled_project_modules
  end

  def test_available_project_modules
    with_plugin_settings 'additionals', disabled_modules: [] do
      assert_includes Redmine::AccessControl.available_project_modules, :news
    end

    with_plugin_settings 'additionals', disabled_modules: %i[news] do
      assert_not Redmine::AccessControl.available_project_modules.include? :news
    end
  end

  def test_disabled_module
    assert_not Redmine::AccessControl.disabled_module?(:not_existing)
    with_plugin_settings 'additionals', disabled_modules: %w[news] do
      assert Redmine::AccessControl.disabled_module?(:news)
    end
    with_plugin_settings 'additionals', disabled_modules: %i[news] do
      assert Redmine::AccessControl.disabled_module?(:news)
    end
  end

  def test_active_module
    assert Redmine::AccessControl.active_module?(:issue_tracking)
    assert_not Redmine::AccessControl.active_module?(:not_existing)

    with_plugin_settings 'additionals', disabled_modules: %i[issue_tracking] do
      assert_not Redmine::AccessControl.active_module?(:issue_tracking)
    end

    assert Redmine::AccessControl.active_module?(:issue_tracking)
  end

  def test_active_entity_module
    assert Redmine::AccessControl.active_entity_module?(Wiki)

    with_plugin_settings 'additionals', disabled_modules: %i[wiki] do
      assert_includes Redmine::AccessControl.disabled_project_modules, :wiki
      assert_not Redmine::AccessControl.active_entity_module?(Wiki)
    end

    assert Redmine::AccessControl.active_entity_module?(Wiki)
  end

  def test_active_entity_module_with_class_without_entity_module_name
    assert_raises NameError do
      Redmine::AccessControl.active_entity_module? Document
    end
  end

  def test_available_search_types_includes_all_by_default
    types = Redmine::Search.available_search_types

    assert_includes types, 'issues'
    assert_includes types, 'news'
    assert_includes types, 'wiki_pages'
  end

  def test_available_search_types_excludes_disabled_modules
    with_plugin_settings 'additionals', disabled_modules: %i[news documents] do
      types = Redmine::Search.available_search_types

      assert_includes types, 'issues'
      assert_not_includes types, 'news'
      assert_not_includes types, 'documents'
      assert_includes types, 'wiki_pages'
    end
  end

  def test_available_search_types_restores_after_settings_change
    with_plugin_settings 'additionals', disabled_modules: %i[boards] do
      assert_not_includes Redmine::Search.available_search_types, 'messages'
    end

    assert_includes Redmine::Search.available_search_types, 'messages'
  end
end
