# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsPluginTest < Additionals::TestCase
  def test_known_plugin
    skip 'Skip test, because redmine_sudo should not be installed for this test.' if Redmine::Plugin.installed? :redmine_sudo

    assert_not AdditionalsPlugin.active_sudo?
  end

  def test_unknown_plugin
    assert_not AdditionalsPlugin.active_unknown?
  end

  # A module that does not exist cannot be disabled
  def test_installed_plugin_without_module_of_its_name_is_active
    with_test_plugin :redmine_additionals_dummy do
      assert AdditionalsPlugin.active_additionals_dummy?
    end
  end

  # Core's wiki module stands in for a module of the plugin's name
  def test_disabled_module_of_installed_plugin_counts_only_without_force
    with_test_plugin :redmine_wiki do
      assert AdditionalsPlugin.active_wiki?

      with_plugin_settings 'additionals', disabled_modules: ['wiki'] do
        assert_not AdditionalsPlugin.active_wiki?
        assert AdditionalsPlugin.active_wiki?(force: true)
      end
    end
  end

  # Plugins register one after another, a check before the registration must not
  # stick to the plugin afterwards
  def test_plugin_registered_after_a_first_check_is_found
    assert_not AdditionalsPlugin.active_additionals_late?

    with_test_plugin :redmine_additionals_late do
      assert AdditionalsPlugin.active_additionals_late?
    end
  end

  # db:create and db:migrate run without the settings table, the module lock is
  # not read then
  def test_check_without_settings_table_uses_installed_modules
    with_test_plugin :redmine_wiki do
      with_plugin_settings 'additionals', disabled_modules: ['wiki'] do
        Redmine::AccessControl.instance_variable_set :@settings_table_ready, false

        assert AdditionalsPlugin.active_wiki?
      ensure
        Redmine::AccessControl.remove_instance_variable :@settings_table_ready
      end
    end
  end

  def test_invalid_method_name_should_raise_error
    assert_raises NoMethodError do
      AdditionalsPlugin.run_unknown?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run_unknown
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.unknown?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run_?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run
    end
  end

  private

  # Registers a plugin for the block only. Its directory has no views and no
  # locales, so registering leaves nothing behind in the view or locale paths.
  def with_test_plugin(id)
    path = File.expand_path '../../fixtures', __FILE__
    Redmine::Plugin.register(id) { directory path }
    yield
  ensure
    Redmine::Plugin.unregister id
  end
end
