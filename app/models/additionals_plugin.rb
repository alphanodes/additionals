# frozen_string_literal: true

class AdditionalsPlugin
  class << self
    def respond_to_missing?(method_name, include_private = false)
      validate_default_plugin_name?(method_name) || super
    end

    def method_missing(method_name, force: false)
      if validate_default_plugin_name? method_name
        default_plugin_check?(method_name, force:)
      else
        super
      end
    end

    # active_<name>? for any plugin redmine_<name>, also of other developers: it is
    # installed and the project module <name> is not disabled. A plugin without a
    # module of its name counts as active, such a module cannot be disabled.
    # With force: true the module is not checked at all.
    def default_plugin_check?(method_name, force: true)
      plugin_name = method_name.to_s[7..-2]
      return false unless Redmine::Plugin.installed? "redmine_#{plugin_name}"

      mod = plugin_name.to_sym
      force || !module_of_plugin?(mod) || Redmine::AccessControl.active_module?(mod)
    end

    # Plugins whose modules are named other than the plugin

    def active_servicedesk_invoices?(force: true)
      Redmine::Plugin.installed?('redmine_servicedesk') && (force || Redmine::AccessControl.active_module?(:invoices))
    end

    def active_servicedesk_helpdesk?(force: true)
      Redmine::Plugin.installed?('redmine_servicedesk') && (force || Redmine::AccessControl.active_module?(:helpdesk))
    end

    def active_servicedesk_contacts?(force: true)
      Redmine::Plugin.installed?('redmine_servicedesk') && (force || Redmine::AccessControl.active_module?(:contacts))
    end

    def active_all_contacts?(force: true)
      Redmine::Plugin.installed?('redmine_servicedesk') && (force || Redmine::AccessControl.active_module?(:contacts)) ||
        Redmine::Plugin.installed?('redmine_contacts') && (force || Redmine::AccessControl.active_module?(:contacts))
    end

    private

    # Redmine creates the modules of a plugin while registering it, before it
    # counts as installed, so the answer for an installed plugin never changes
    def module_of_plugin?(mod)
      @module_of_plugin ||= {}
      return @module_of_plugin[mod] if @module_of_plugin.key? mod

      @module_of_plugin[mod] = Redmine::AccessControl.available_project_modules_all.include? mod
    end

    def validate_default_plugin_name?(method_name)
      method_name.to_s.start_with?('active_') && method_name.to_s.end_with?('?')
    end
  end
end
