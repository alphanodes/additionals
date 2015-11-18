# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015  AlphaNodes GmbH

# Redmine Tweak helper functions
module RedmineTweaks
  module Helper
    def system_uptime
      if windows_platform?
        `net stats srv | find "Statist"`
      else
        if File.exist?('/proc/uptime')
          secs = "#{`cat /proc/uptime`}".to_i
          min = 0
          hours = 0
          days = 0
          if secs>0
            min = (secs / 60).round
            hours = (secs / 3600).round
            days = (secs / 86400).round
          end
          if days >= 1
            "#{days} #{l(:days, count: days)}"
          elsif hours >= 1
            "#{hours} #{l(:hours, count: hours)}"
          else
            "#{min} #{l(:minutes, count: min)}"
          end
        else
          days = "#{`uptime | awk '{print $3}'`}".to_i.round
          "#{days} #{l(:days, count: days)}"
        end
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
  end
end

ActionView::Base.send :include, RedmineTweaks::Helper
