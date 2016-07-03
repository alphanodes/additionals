# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

module RedmineTweaks
  module Patches
    module IssuePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :editable?, :closed_edit
          validate :validate_open_sub_issues
          validate :validate_current_user_status
          before_save :change_status_with_assigned_to_change
        end
      end

      # Instance methods with helper functions
      module InstanceMethods
        def editable_with_closed_edit?(user = User.current)
          return unless editable_without_closed_edit?(user)
          return true unless closed?
          user.allowed_to?(:edit_closed_issues, project)
        end
      end

      def new_ticket_message
        @new_ticket_message = ''
        message = Setting.plugin_redmine_tweaks['new_ticket_message']
        @new_ticket_message << message unless message.blank?
      end

      private

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
