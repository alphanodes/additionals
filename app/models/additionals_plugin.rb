# frozen_string_literal: true

class AdditionalsPlugin
  class << self
    def respond_to_missing?(method_name, include_private = false)
      validate_default_plugin_name(method_name) || super
    end

    def method_missing(method_name, force: false)
      if validate_default_plugin_name method_name
        default_plugin_check? method_name, force: force
      else
        super
      end
    end

    # if force: true, no access control check for disabled module
    def default_plugin_check?(method_name, force: true)
      plugin_name = method_name.to_s[7..-2]
      Redmine::Plugin.installed?("redmine_#{plugin_name}") && (force || Redmine::AccessControl.active_module?(plugin_name.to_sym))
    end

    def active_reporting?
      @active_reporting ||= Redmine::Plugin.installed? 'redmine_reporting'
    end

    def active_hrm?
      @active_hrm ||= Redmine::Plugin.installed? 'redmine_hrm'
    end

    def active_sudo?
      @active_sudo ||= Redmine::Plugin.installed? 'redmine_sudo'
    end

    def active_servicedesk?
      @active_servicedesk ||= Redmine::Plugin.installed? 'redmine_servicedesk'
    end

    def active_canned_responses?(force: true)
      Redmine::Plugin.installed?('redmine_servicedesk') && (force || Redmine::AccessControl.active_module?(:canned_responses))
    end

    def active_invoices?(force: true)
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

    def validate_default_plugin_name(method_name)
      method_name.to_s.start_with?('active_') && method_name.to_s.end_with?('?')
    end
  end
end
