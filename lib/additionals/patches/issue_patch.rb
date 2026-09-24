# frozen_string_literal: true

module Additionals
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods
        # EntityMethodsGlobal is meant for every entity including core ones, but
        # Issue only received it because additional_tags happened to mix it in.
        # Plugins call Issue.load_visible_notes_count and friends, so the entity
        # this plugin family revolves around has to carry them on its own.
        include Additionals::EntityMethodsGlobal

        validate :validate_change_on_closed
        validate :validate_timelog_required
        validate :validate_current_user_status
        before_validation :auto_assigned_to
        before_save :change_status_with_assigned_to_change

        # Redmine core auto-watches the assignee only when the assignment changes
        # on an existing issue (Journal#watchable_users, issue_assigned_to_me
        # preference); it does not cover assigning directly on issue creation.
        # Fill that gap here using the same core preference.
        after_create_commit :add_assigned_watcher

        # Dashboard "query list" blocks are wrapped in a TTL-based fragment
        # cache (see DashboardsHelper#dashboard_async_cache), so a change made
        # out-of-band (REST API, bulk edit, a third-party quick-edit plugin)
        # would otherwise stay invisible on the project overview page until
        # the cache entry expires, no matter how the frontend is told to reload.
        after_commit :expire_dashboard_query_list_caches, on: %i[create update destroy]

        safe_attributes 'author_id',
                        if: proc { |issue, user|
                          issue.new_record? && user.allowed_to?(:change_new_issue_author, issue.project) ||
                            issue.persisted? && user.allowed_to?(:edit_issue_author, issue.project)
                        }
      end

      class_methods do
        def join_issue_status(is_closed: nil)
          sql = "JOIN #{IssueStatus.table_name} ON #{IssueStatus.table_name}.id = #{table_name}.status_id"
          return sql if is_closed.nil?

          sql << " AND #{IssueStatus.table_name}.is_closed = #{is_closed ? connection.quoted_true : connection.quoted_false}"
          sql
        end
      end

      module InstanceOverwriteMethods
        def editable?(user = User.current)
          return false unless super
          return true unless closed?
          return true unless Additionals.setting? :issue_freezed_with_close

          user.allowed_to? :edit_closed_issues, project
        end
      end

      module InstanceMethods
        def add_assigned_watcher
          return unless assigned_to.is_a? User
          return unless assigned_to.pref.auto_watch_on? 'issue_assigned_to_me'
          return if watcher_user_ids.include? assigned_to_id
          return unless assigned_to.active?

          set_watcher assigned_to, true
        end

        def sidebar_change_status_allowed_to(user, new_status_id = nil)
          statuses = new_statuses_allowed_to user
          if new_status_id.present?
            statuses.detect { |s| new_status_id == s.id && !timelog_required?(s.id) }
          else
            statuses.reject { |s| timelog_required? s.id }
          end
        end
      end

      def new_ticket_message
        project.active_new_ticket_message
      end

      def status_x_affected?(new_status_id)
        return false unless Additionals.setting? :issue_current_user_status
        return false if Additionals.setting(:issue_assign_to_x).blank?

        Additionals.setting(:issue_assign_to_x).include? new_status_id.to_s
      end

      private

      # Rails.cache (FileStore by default) supports pattern-based deletion,
      # so we can drop every dashboard async-block fragment scoped to this
      # project without knowing the exact block/settings combination that
      # produced it. The cache key format is fixed by
      # AdditionalsRenderAsyncHelper#render_async_cache_key /
      # DashboardsHelper#dashboard_async_cache: "views/render_async_<path>",
      # where <path> is the project-scoped dashboard_async_blocks route
      # (see config/routes.rb), so matching on that path prefix is stable
      # regardless of query-string param order.
      #
      # This only reaches project dashboards (where the project identifier is
      # part of the URL path). A global/welcome dashboard's cross-project
      # query blocks are not addressed here.
      def expire_dashboard_query_list_caches
        return if project.blank?

        Rails.cache.delete_matched(%r{\Aviews/render_async_/projects/#{Regexp.escape project.to_param.to_s}/dashboard_async_blocks})
      end

      def auto_assigned_to
        return if !Additionals.setting?(:issue_auto_assign) ||
                  Additionals.setting(:issue_auto_assign_status).blank? ||
                  Additionals.setting(:issue_auto_assign_role).blank? ||
                  assigned_to_id.present?

        return unless Additionals.setting(:issue_auto_assign_status).include?(status_id.to_s)

        user_id = auto_assigned_user_id
        self.assigned_to_id = user_id if user_id.present?
      end

      def auto_assigned_user_id
        manager_role = Role.builtin.find_by id: Additionals.setting(:issue_auto_assign_role)
        groups = autoassign_get_group_list
        return groups[manager_role].first.id unless groups.nil? || groups[manager_role].blank?

        principals_by_role = project.principals_by_role
        return if principals_by_role[manager_role].blank?

        users_list = principals_by_role[manager_role].grep User
        return if users_list.blank?

        users_list.first.id
      end

      def autoassign_get_group_list
        return unless Setting.issue_group_assignment?

        project.memberships
               .active
               .where(users: { type: 'Group' })
               .includes(:user, :roles)
               .each_with_object({}) do |m, h|
          m.roles.each do |r|
            h[r] ||= []
            h[r] << m.principal
          end
          h
        end
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
