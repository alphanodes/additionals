# frozen_string_literal: true

module Additionals
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      USABLE_STATUSES = { Project::STATUS_ACTIVE => :active,
                          Project::STATUS_CLOSED => :closed }.freeze

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods

        has_many :dashboards, dependent: :destroy

        safe_attributes 'enable_new_ticket_message', 'new_ticket_message'
      end

      class_methods do
        def usable_status_ids
          USABLE_STATUSES.keys
        end

        def sql_for_usable_status(table = nil)
          table ||= Project.table_name

          "#{table}.status IN(#{usable_status_ids.join ', '})"
        end

        def available_status_ids
          available_statuses.keys
        end

        def available_statuses
          statuses = USABLE_STATUSES.dup
          statuses[Project::STATUS_ARCHIVED] = :archived
          statuses[Project::STATUS_SCHEDULED_FOR_DELETION] = :scheduled_for_deletion

          statuses
        end
      end

      module InstanceOverwriteMethods
        def assignable_users(tracker = nil)
          # Cache users per project, tracker AND user context to avoid repeated queries
          # CRITICAL: Cache must be user-specific because hidden roles visibility depends on User.current
          @assignable_users ||= {}

          # Create cache key that includes user context for hidden roles security
          user_cache_key = if User.current.admin? || User.current.allowed_to?(:show_hidden_roles_in_memberbox, self)
                             "admin_#{tracker}"
                           else
                             "user_#{tracker}"
                           end

          return @assignable_users[user_cache_key] if @assignable_users.key? user_cache_key

          # Use Issue-specific implementation if tracker is provided (Issues only!)
          # Otherwise use general project assignable users (for other entities)
          users = if tracker
                    ::Additionals::AssignableUsersOptimizer.issue_assignable_users self, tracker: tracker
                  else
                    ::Additionals::AssignableUsersOptimizer.project_assignable_users self
                  end

          @assignable_users[user_cache_key] = users
        end

        # Clear assignable users cache when members change
        # This is critical for consistency when users/roles are added/removed
        def reload(*args)
          @assignable_users = nil
          super
        end

        def principals_by_role
          return super unless consider_hidden_roles?

          includes = %i[principal member_roles roles]
          memberships.active.includes(includes).each_with_object({}) do |m, h|
            m.roles.each do |r|
              next if r.hide

              h[r] ||= []
              h[r] << m.principal
            end
            h
          end
        end
      end

      module InstanceMethods
        def consider_hidden_roles?
          return @with_hidden_roles if defined? @with_hidden_roles

          @with_hidden_roles = false
          return @with_hidden_roles if User.current.allowed_to? :show_hidden_roles_in_memberbox, self

          @with_hidden_roles = Role.exists? hide: true, users_visibility: 'members_of_visible_projects'
          @with_hidden_roles
        end

        # without hidden roles!
        def all_principals_by_role
          memberships.includes(:principal, :roles).each_with_object({}) do |m, h|
            m.roles.each do |r|
              h[r] ||= []
              h[r] << m.principal
            end
            h
          end
        end

        def visible_principals
          query = ::Query.new project: self, name: '_'
          query&.principals
        end

        def visible_users
          query = ::Query.new project: self, name: '_'
          query&.users
        end

        # assignable_users result depends on Setting.issue_group_assignment?
        # this result is not depending on issue settings
        #
        # - always with groups and users
        # - no tracker support -> cannot be used with issues
        def assignable_principals
          Principal.assignable
                   .joins(members: :roles)
                   .where(members: { project_id: id },
                          roles: { assignable: true })
                   .distinct
                   .sorted
        end

        def active_new_ticket_message
          @active_new_ticket_message = if enable_new_ticket_message.positive? && User.current.allowed_to?(:view_issues, self)
                                         if enable_new_ticket_message == 1
                                           Additionals.setting(:new_ticket_message).presence || ''
                                         else
                                           new_ticket_message.presence || ''
                                         end
                                       else
                                         ''
                                       end
        end
      end
    end
  end
end
