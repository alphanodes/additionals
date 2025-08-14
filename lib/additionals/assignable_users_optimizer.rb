# frozen_string_literal: true

module Additionals
  # Optimized assignable users logic abstracted from Project and TimeEntry implementations
  # This module provides N+1 query-free implementations with proper hidden roles support
  module AssignableUsersOptimizer
    extend ActiveSupport::Concern

    module_function

    # Optimized implementation for project-based assignable users
    # @param project [Project] The project to get assignable users for
    # @return [Array<User>] Array of assignable users
    def project_assignable_users(project)
      return [] unless project

      # Find roles that are assignable and have the required permission
      assignable_role_ids = Role.where(assignable: true).pluck(:id)
      return [] if assignable_role_ids.empty?

      # Apply hidden roles filter if needed
      # CRITICAL SECURITY: Only admin users and users with show_hidden_roles_in_memberbox permission
      # should see users with hidden roles
      unless User.current.admin? || User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)
        # Regular users should not see users with hidden roles
        visible_role_ids = Role.where(id: assignable_role_ids, hide: false).pluck(:id)
        assignable_role_ids &= visible_role_ids
        return [] if assignable_role_ids.empty?
      end

      # Get users/principals with these roles in this project
      # NOTE: For general assignable users, we include both users and groups if group assignment is enabled
      types = ['User']
      types << 'Group' if Setting.issue_group_assignment?

      users = Principal.active
                       .joins(members: :roles)
                       .where(type: types,
                              members: { project_id: project.id },
                              roles: { id: assignable_role_ids })
                       .distinct
                       .sorted
                       .to_a

      # Add current user if they have assignable roles but aren't in the list
      if User.current.logged? && users.exclude?(User.current)
        # Quick check if current user has assignable roles in this project
        current_user_assignable = User.current.members
                                      .joins(:roles)
                                      .exists?(project_id: project.id, roles: { id: assignable_role_ids })
        users << User.current if current_user_assignable
      end

      users
    end

    # Special implementation for Issue assignable users (with tracker support)
    # This is the ONLY entity that needs tracker-specific logic
    # @param project [Project] The project to get assignable users for
    # @param tracker [Tracker, nil] Optional tracker for workflow filtering
    # @return [Array<User>] Array of assignable users
    def issue_assignable_users(project, tracker: nil)
      return [] unless project

      # Start with basic project assignable users for issues
      # NOTE: We call the method directly to ensure fresh results for tracker-specific calls
      users = project_assignable_users project
      return users unless tracker

      # Apply tracker-specific workflow filtering - OPTIMIZED to avoid N+1
      return users unless defined?(WorkflowTransition)

      # Get all workflow role IDs for this tracker in a single query (instead of N+1)
      workflow_role_ids = WorkflowTransition
                          .where(tracker_id: tracker.id)
                          .distinct
                          .pluck(:role_id)

      return users if workflow_role_ids.empty?

      # Get principal-role mappings for all users/groups in a single query (instead of N+1)
      # Note: Members table uses user_id column for both Users and Groups (all Principals)
      principal_ids = users.map(&:id)
      principals_with_workflow_roles = Member
                                       .joins(:roles)
                                       .where(project_id: project.id,
                                              user_id: principal_ids,
                                              roles: { id: workflow_role_ids })
                                       .distinct
                                       .pluck(:user_id)
                                       .to_set

      # Filter users/groups based on workflow role availability
      users.select { |principal| principals_with_workflow_roles.include? principal.id }
    end

    # Optimized implementation for log_time specific users
    # @param project [Project] The project to get log time users for
    # @return [Array<User>] Array of users who can log time
    def log_time_assignable_users(project)
      return [] unless project

      # Find roles that have log_time permission (stored as YAML in permissions column)
      log_time_role_ids = Role.where("permissions LIKE '%:log_time%' OR permissions LIKE '%- :log_time%'")
                              .pluck(:id)

      return [] if log_time_role_ids.empty?

      # Apply hidden roles filter if needed
      # Only admin users and users with show_hidden_roles_in_memberbox permission should see users with hidden roles
      unless User.current.admin? || User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)
        visible_role_ids = Role.where(id: log_time_role_ids, hide: false).pluck(:id)
        log_time_role_ids &= visible_role_ids
        return [] if log_time_role_ids.empty?
      end

      # Single optimized query to get all users with log_time permission
      users = User.joins(members: :roles)
                  .where(members: { project_id: project.id },
                         roles: { id: log_time_role_ids },
                         status: User::STATUS_ACTIVE)
                  .distinct
                  .to_a

      # Add current user if they can log time but aren't in the list
      if User.current.logged? &&
         users.exclude?(User.current) &&
         User.current.allowed_to?(:log_time, project)
        users << User.current
      end

      users
    end

    # Optimized implementation for global assignable users (when no project context)
    # @return [Array<Principal>] Array of globally assignable principals
    def global_assignable_users
      # Find roles that are assignable - use SQL to avoid N+1
      # Note: This is a simplified approach since checking permissions globally is complex
      # For now, we get assignable roles and assume view_issues permission
      assignable_role_ids = Role.where(assignable: true).pluck(:id)
      return [] if assignable_role_ids.empty?

      # Apply hidden roles filter if needed - only admins should see users with hidden roles
      unless User.current.admin?
        visible_role_ids = Role.where(id: assignable_role_ids, hide: false).pluck(:id)
        assignable_role_ids &= visible_role_ids
        return [] if assignable_role_ids.empty?
      end

      # This is still not ideal as it gets all users globally, but better than the original
      # In practice, this should rarely be used - most entities should have project context
      types = ['User']
      types << 'Group' if Setting.issue_group_assignment?

      users = Principal.active
                       .joins(members: :roles)
                       .where(type: types, roles: { id: assignable_role_ids })
                       .distinct
                       .to_a

      # Add current user if logged and has assignable roles globally
      if User.current.logged? && users.exclude?(User.current)
        # Check if user has any assignable roles globally
        user_has_assignable_roles = User.current.members.joins(:roles).exists?(roles: { id: assignable_role_ids })
        users << User.current if user_has_assignable_roles
      end

      users.uniq!
      users.sort
    end
  end
end
