# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :editable?, :closed_edit
          # TODO: working on issues of dependencies (aroud 20 redmine tests failed with it)
          # validate :validate_change_on_closed
          validate :validate_open_sub_issues
          validate :validate_current_user_status
          before_save :change_status_with_assigned_to_change
        end
      end

      # Instance methods with helper functions
      module InstanceMethods
        def log_time_allowed?(user = User.current)
          !closed? || user.allowed_to?(:log_time_on_closed_issues, project)
        end

        def editable_with_closed_edit?(user = User.current)
          return false unless editable_without_closed_edit?(user)
          return true unless closed?
          user.allowed_to?(:edit_closed_issues, project)
        end
      end

      def auto_assign_user
        manager_role = Role.builtin.find(RedmineTweaks.settings[:issue_auto_assign_role].to_i)
        groups = autoassign_get_group_list
        return groups[manager_role].first.id unless groups.nil? || groups[manager_role].blank?

        users_list = project.users_by_role
        return users_list[manager_role].first.id if users_list[manager_role].present?
      end

      def autoassign_get_group_list
        return unless Setting.issue_group_assignment?
        project.memberships
               .active
               .where("#{Principal.table_name}.type='Group'")
               .includes(:user, :roles)
               .each_with_object({}) do |m, h|
          m.roles.each do |r|
            h[r] ||= []
            h[r] << m.principal
          end
          h
        end
      end

      def new_ticket_message
        @new_ticket_message = ''
        message = Setting.plugin_redmine_tweaks[:new_ticket_message]
        @new_ticket_message << message if message.present?
      end

      private

      def validate_change_on_closed
        return true unless closed?
        errors.add :base, :issue_changes_not_allowed unless User.current.allowed_to?(:edit_closed_issues, project)
      end

      def validate_open_sub_issues
        return true unless RedmineTweaks.settings[:issue_close_with_open_children]
        errors.add :base, :issue_cannot_close_with_open_children if subject.present? &&
                                                                    closing? &&
                                                                    descendants.find { |d| !d.closed? }
      end

      def validate_current_user_status
        return true unless RedmineTweaks.settings[:issue_current_user_status]
        return true if RedmineTweaks.settings[:issue_assign_to_x].nil?
        if (assigned_to_id_changed? || status_id_changed?) &&
           (RedmineTweaks.settings[:issue_assign_to_x].include?status_id.to_s) &&
           (assigned_to_id.blank? || assigned_to_id != User.current.id)
          errors.add :base, :issue_current_user_status
        end
      end

      def change_status_with_assigned_to_change
        return true unless RedmineTweaks.settings[:issue_status_change]
        return true if RedmineTweaks.settings[:issue_status_x].nil?
        return true if RedmineTweaks.settings[:issue_status_y].nil?
        if !assigned_to_id_changed? &&
           status_id_changed? &&
           (RedmineTweaks.settings[:issue_status_x].include?status_id_was.to_s) &&
           RedmineTweaks.settings[:issue_status_y].to_i == status_id
          self.assigned_to = author
        end
      end
    end
  end
end

unless Issue.included_modules.include? RedmineTweaks::Patches::IssuePatch
  Issue.send(:include, RedmineTweaks::Patches::IssuePatch)
end
