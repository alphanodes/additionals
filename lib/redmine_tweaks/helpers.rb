# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

# Redmine Tweak helper functions
module RedmineTweaks
  module Helpers
    def system_uptime
      if windows_platform?
        `net stats srv | find "Statist"`
      elsif File.exist?('/proc/uptime')
        secs = `cat /proc/uptime`.to_i
        min = 0
        hours = 0
        days = 0
        if secs > 0
          min = (secs / 60).round
          hours = (secs / 3_600).round
          days = (secs / 86_400).round
        end
        if days >= 1
          "#{days} #{l(:days, count: days)}"
        elsif hours >= 1
          "#{hours} #{l(:hours, count: hours)}"
        else
          "#{min} #{l(:minutes, count: min)}"
        end
      else
        days = `uptime | awk '{print $3}'`.to_i.round
        "#{days} #{l(:days, count: days)}"
      end
    end

    def system_info
      if windows_platform?
        'unknown'
      else
        `uname -a`
      end
    end

    def windows_platform?
      true if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
    end

    def memberbox_view_roles
      view_roles = []
      @users_by_role.keys.sort.each do |role|
        if !role.permissions.include?(:hide_in_memberbox) ||
           (role.permissions.include?(:hide_in_memberbox) && User.current.allowed_to?(:show_hidden_roles_in_memberbox, @project))
          view_roles << role
        end
      end
      view_roles
    end

    def add_top_menu_custom_item(i, user_roles)
      menu_name = 'custom_menu' + i.to_s
      item = {
        url: Setting.plugin_redmine_tweaks[menu_name + '_url'],
        name: Setting.plugin_redmine_tweaks[menu_name + '_name'],
        title: Setting.plugin_redmine_tweaks[menu_name + '_title'],
        roles: Setting.plugin_redmine_tweaks[menu_name + '_roles']
      }
      return if item[:name].blank? || item[:url].blank? || item[:roles].nil?

      show_entry = false
      item[:roles].each do |role|
        if user_roles.empty? && role.to_i == Role::BUILTIN_ANONYMOUS
          show_entry = true
          break
        elsif User.current.logged? && role.to_i == Role::BUILTIN_NON_MEMBER
          # if user is logged in and non_member is active in item,
          # always show it
          show_entry = true
          break
        end

        user_roles.each do |user_role|
          if role.to_i == user_role.id.to_i
            show_entry = true
            break
          end
        end
        break if show_entry == true
      end
      handle_top_menu_item(menu_name, item, show_entry)
    end

    def handle_top_menu_item(menu_name, item, show_entry = false)
      if Redmine::MenuManager.map(:top_menu).exists?(menu_name.to_sym)
        Redmine::MenuManager.map(:top_menu).delete(menu_name.to_sym)
      end
      return unless show_entry

      html_options = {}
      html_options[:class] = 'external' if item[:url].include? '://'
      html_options[:title] = item[:title] unless item[:title].blank?
      Redmine::MenuManager.map(:top_menu).push menu_name,
                                               item[:url],
                                               caption: item[:name].to_s,
                                               html: html_options,
                                               before: :help
    end

    def bootstrap_datepicker_locale
      s = ''
      locale = User.current.language.blank? ? ::I18n.locale : User.current.language
      s = javascript_include_tag("locales/bootstrap-datepicker.#{locale}.min", plugin: 'redmine_tweaks') unless locale == 'en'
      s
    end
  end
end

ActionView::Base.send :include, RedmineTweaks::Helpers
