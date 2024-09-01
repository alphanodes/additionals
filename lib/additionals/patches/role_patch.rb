# frozen_string_literal: true

module Additionals
  module Patches
    module RolePatch
      extend ActiveSupport::Concern

      included do
        safe_attributes 'hide'
      end

      class_methods do
        def visible(user = User.current)
          if user.admin? ||
             user.allowed_to?(:show_hidden_roles_in_memberbox, nil, global: true) ||
             AdditionalsPlugin.active_hrm? && User.current.hrm_allowed_to?(:view_hrm)
            all
          else
            where hide: false
          end
        end
      end
    end
  end
end
