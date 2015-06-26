# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

module RedmineTweaks

    module IssuePatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :editable?, :closed_edit
        end
      end

      # Instance methods with helper functions
      module InstanceMethods
        def editable_with_closed_edit?(user=User.current)
          if editable_without_closed_edit?(user)
            if self.closed?
              user.allowed_to?(:edit_closed_issues, project)
            else
              true
            end
          end
        end
      end

      def new_ticket_message
        @new_ticket_message = ''
        @new_ticket_message << Setting.plugin_redmine_tweaks['new_ticket_message']
      end
    end

end
