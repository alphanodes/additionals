# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015  AlphaNodes GmbH

# Redmine Tweak helper functions
module RedmineTweaks
  module Helper
    def system_uptime
      if windows_platform?
        `net stats srv | find "Statist"`
      else
        "#{`uptime | awk '{print $3}'`} #{l(:days)}"
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
