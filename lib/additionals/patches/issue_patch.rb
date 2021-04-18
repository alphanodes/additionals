# frozen_string_literal: true

module Additionals
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        alias_method :editable_without_additionals?, :editable?
        alias_method :editable?, :editable_with_additionals?
        validate :validate_change_on_closed
        validate :validate_timelog_required
        validate :validate_current_user_status
        before_validation :auto_assigned_to
        before_save :change_status_with_assigned_to_change,
                    :autowatch_involved

        safe_attributes 'author_id',
                        if: proc { |issue, user|
                          issue.new_record? && user.allowed_to?(:change_new_issue_author, issue.project) ||
                            issue.persisted? && user.allowed_to?(:edit_issue_author, issue.project)
                        }
      end

      class_methods do
        def join_issue_status(is_closed: nil)
          sql = +"JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{table_name}.status_id"
          return sql if is_closed.nil?

          sql << " AND #{IssueStatus.table_name}.is_closed = #{is_closed ? connection.quoted_true : connection.quoted_false}"
          sql
        end
      end

      module InstanceMethods
        def sidbar_change_status_allowed_to(user, new_status_id = nil)
          statuses = new_statuses_allowed_to user
          if new_status_id.present?
            statuses.detect { |s| new_status_id == s.id && !timelog_required?(s.id) }
          else
            statuses.reject { |s| timelog_required? s.id }
          end
        end

        def add_autowatcher(watcher)
          return if watcher.nil? ||
                    !watcher.is_a?(User) ||
                    watcher.anonymous? ||
                    !watcher.active? ||
                    watched_by?(watcher)

          add_watcher watcher
        end

        def autowatch_involved
          return unless Additionals.setting?(:issue_autowatch_involved) &&
                        User.current.pref.autowatch_involved_issue
          return if Redmine::Plugin.installed?('redmine_automation') && author_id == RedmineAutomation.bot_user_id

          add_autowatcher User.current
          add_autowatcher author if (new_record? || author_id != author_id_was) && author != User.current

          if !assigned_to_id.nil? && assigned_to_id != User.current.id && (new_record? || assigned_to_id != assigned_to_id_was)
            add_autowatcher assigned_to
          end

          true
        end

        def log_time_allowed?(user = User.current)
          !status_was.is_closed || user.allowed_to?(:log_time_on_closed_issues, project)
        end

        def editable_with_additionals?(user = User.current)
          return false unless editable_without_additionals? user
          return true unless closed?
          return true unless Additionals.setting? :issue_freezed_with_close

          user.allowed_to? :edit_closed_issues, project
        end
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
        @new_ticket_message ||= Additionals.setting(:new_ticket_message).presence || ''
      end

      def status_x_affected?(new_status_id)
        return false unless Additionals.setting? :issue_current_user_status
        return false if Additionals.setting(:issue_assign_to_x).blank?

        Additionals.setting(:issue_assign_to_x).include? new_status_id.to_s
      end

      private

      def auto_assigned_to
        return if !Additionals.setting?(:issue_auto_assign) ||
                  Additionals.setting(:issue_auto_assign_status).blank? ||
                  Additionals.setting(:issue_auto_assign_role).blank? ||
                  assigned_to_id.present?

        return unless Additionals.setting(:issue_auto_assign_status).include?(status_id.to_s)

        self.assigned_to_id = auto_assigned_to_user
        true
      end

      def auto_assigned_to_user
        manager_role = Role.builtin.find_by id: Additionals.setting(:issue_auto_assign_role)
        groups = autoassign_get_group_list
        return groups[manager_role].first.id unless groups.nil? || groups[manager_role].blank?

        users_list = project.users_by_role
        return users_list[manager_role].first.id if users_list[manager_role].present?
      end

      def timelog_required?(check_status_id)
        usr = User.current
        return false if !Additionals.setting?(:issue_timelog_required) ||
                        Additionals.setting(:issue_timelog_required_tracker).blank? ||
                        Additionals.setting(:issue_timelog_required_tracker).exclude?(tracker_id.to_s) ||
                        Additionals.setting(:issue_timelog_required_status).blank? ||
                        Additionals.setting(:issue_timelog_required_status).exclude?(check_status_id.to_s) ||
                        !usr.allowed_to?(:log_time, project) ||
                        usr.allowed_to?(:issue_timelog_never_required, project) ||
                        time_entries.present?

        true
      end

      def validate_timelog_required
        return true unless timelog_required? status_id

        errors.add :base, :issue_requires_timelog
      end

      def validate_change_on_closed
        return true if new_record? ||
                       !status_was.is_closed ||
                       !changed? ||
                       !Additionals.setting?(:issue_freezed_with_close) ||
                       User.current.allowed_to?(:edit_closed_issues, project)

        errors.add :base, :issue_changes_not_allowed
      end

      def validate_current_user_status
        if (assigned_to_id_changed? || status_id_changed?) &&
           status_x_affected?(status_id) &&
           (assigned_to_id.blank? || assigned_to_id != User.current.id)
          errors.add :base, :issue_current_user_status
        else
          true
        end
      end

      def change_status_with_assigned_to_change
        return true if !Additionals.setting?(:issue_status_change) ||
                       Additionals.setting(:issue_status_x).blank? ||
                       Additionals.setting(:issue_status_y).blank?

        if !assigned_to_id_changed? &&
           status_id_changed? &&
           (Additionals.setting(:issue_status_x).include? status_id_was.to_s) &&
           Additionals.setting(:issue_status_y).to_i == status_id
          self.assigned_to = author
        end
      end
    end
  end
end
