# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015  AlphaNodes GmbH

# Redmine Tweak helper functions
module RedmineTweaks
  module Helper
    def get_memberbox_view_roles
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
