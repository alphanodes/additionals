# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class RedmineAccessControlTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :roles

  def setup
    prepare_tests
  end

  def test_available_project_modules_all
    assert Redmine::AccessControl.available_project_modules_all.is_a? Array
  end

  def test_disabled_project_modules
    assert_equal [], Redmine::AccessControl.disabled_project_modules

    with_additionals_settings disabled_modules: %i[news] do
      assert_equal [:news], Redmine::AccessControl.disabled_project_modules
    end

    assert_equal [], Redmine::AccessControl.disabled_project_modules
  end

  def test_available_project_modules
    with_additionals_settings disabled_modules: [] do
      assert Redmine::AccessControl.available_project_modules.include? :news
    end

    with_additionals_settings disabled_modules: %i[news] do
      assert_not Redmine::AccessControl.available_project_modules.include? :news
    end
  end

  def test_disabled_module
    assert_not Redmine::AccessControl.disabled_module?(:not_existing)
    with_additionals_settings disabled_modules: %w[news] do
      assert Redmine::AccessControl.disabled_module?(:news)
    end
    with_additionals_settings disabled_modules: %i[news] do
      assert Redmine::AccessControl.disabled_module?(:news)
    end
  end

  def test_active_module
    assert Redmine::AccessControl.active_module?(:issue_tracking)
    assert_not Redmine::AccessControl.active_module?(:not_existing)

    with_additionals_settings disabled_modules: %i[issue_tracking] do
      assert_not Redmine::AccessControl.active_module?(:issue_tracking)
    end

    assert Redmine::AccessControl.active_module?(:issue_tracking)
  end

  def test_active_entity_module
    assert Redmine::AccessControl.active_entity_module?(Wiki)

    with_additionals_settings disabled_modules: %i[wiki] do
      assert Redmine::AccessControl.disabled_project_modules.include?(:wiki)
      assert_not Redmine::AccessControl.active_entity_module?(Wiki)
    end

    assert Redmine::AccessControl.active_entity_module?(Wiki)
  end

  def test_active_entity_module_with_class_without_entity_module_name
    assert_raises NameError do
      Redmine::AccessControl.active_entity_module? Document
    end
  end
end
