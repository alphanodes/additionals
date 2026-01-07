# frozen_string_literal: true

module Additionals
  # Optimized assignable users logic abstracted from Project and TimeEntry implementations
  # This module provides N+1 query-free implementations with proper hidden roles support
  module AssignableUsersOptimizer
    extend ActiveSupport::Concern

    module_function

    # ==========================================
    # CORE SECURITY: Hidden Roles Filter Logic
    # ==========================================
    # All methods MUST use these helper methods to ensure consistent hidden roles handling.
    # CRITICAL SECURITY: Only admin users and users with show_hidden_roles_in_memberbox permission
    # should see users with hidden roles.

    # Check if current user can see users with hidden roles
    # @param project [Project, nil] The project context (nil for global check)
    # @return [Boolean] true if current user can see hidden roles
    def can_see_hidden_roles?(project = nil)
      return true if User.current.admin?

      if project
        User.current.allowed_to? :show_hidden_roles_in_memberbox, project
      else
        User.current.allowed_to? :show_hidden_roles_in_memberbox, nil, global: true
      end
    end

    # Filter role IDs to only include visible ones for current user
    # @param role_ids [Array<Integer>] Role IDs to filter
    # @param project [Project, nil] The project context (nil for global check)
    # @return [Array<Integer>] Filtered role IDs (only visible ones for current user)
    def filter_visible_role_ids(role_ids, project: nil)
      return role_ids if role_ids.empty?
      return role_ids if can_see_hidden_roles? project

      # Regular users should not see users with hidden roles
      visible_role_ids = Role.where(id: role_ids, hide: false).pluck(:id)
      role_ids & visible_role_ids
    end

    # Get visible assignable role IDs for current user
    # @param project [Project, nil] The project context
    # @return [Array<Integer>] Visible assignable role IDs
    def visible_assignable_role_ids(project: nil)
      assignable_role_ids = Role.where(assignable: true).pluck(:id)
      filter_visible_role_ids assignable_role_ids, project: project
    end

    # Get principal types based on group assignment setting
    # @return [Array<String>] Principal types to include
    def assignable_principal_types
      types = ['User']
      types << 'Group' if Setting.issue_group_assignment?
      types
    end

    # ==========================================
    # Public API Methods
    # ==========================================

    # Optimized implementation that returns ActiveRecord::Relation for backward compatibility
    # @param project [Project] The project to get assignable users for
    # @return [ActiveRecord::Relation] Relation of assignable users
    def project_assignable_users_relation(project)
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION unless project

      role_ids = visible_assignable_role_ids project: project
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION if role_ids.empty?

      # Use SQL subquery to avoid DISTINCT + ORDER BY problems
      subquery = Principal.active
                          .joins(members: :roles)
                          .where(type: assignable_principal_types,
                                 members: { project_id: project.id },
                                 roles: { id: role_ids })
                          .distinct
                          .select(:id)

      Principal.active
               .where(id: subquery)
               .order(:lastname, :firstname)
    end

    # Array-based implementation for internal use where performance is critical
    # @param project [Project] The project to get assignable users for
    # @return [Array<User>] Array of assignable users
    def project_assignable_users(project)
      return [] unless project

      role_ids = visible_assignable_role_ids project: project
      return [] if role_ids.empty?

      users = Principal.active
                       .joins(members: :roles)
                       .where(type: assignable_principal_types,
                              members: { project_id: project.id },
                              roles: { id: role_ids })
                       .distinct
                       .sorted
                       .to_a

      # Add current user if they have assignable roles but aren't in the list
      if User.current.logged? && users.exclude?(User.current)
        current_user_assignable = User.current.members
                                      .joins(:roles)
                                      .exists?(project_id: project.id, roles: { id: role_ids })
        users << User.current if current_user_assignable
      end

      users
    end

    # Issue assignable users returning ActiveRecord::Relation for backward compatibility
    # @param project [Project] The project to get assignable users for
    # @param tracker [Tracker, nil] Optional tracker for workflow filtering
    # @return [ActiveRecord::Relation] Relation of assignable users
    def issue_assignable_users_relation(project, tracker: nil)
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION unless project

      # No tracker filtering needed, use basic project assignable users
      return project_assignable_users_relation project unless tracker && defined?(WorkflowTransition)

      role_ids = visible_assignable_role_ids project: project
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION if role_ids.empty?

      # Get workflow role IDs for this tracker
      workflow_role_ids = WorkflowTransition
                          .where(tracker_id: tracker.id)
                          .distinct
                          .pluck(:role_id)

      # If no workflow rules exist for this tracker, return all assignable users
      return project_assignable_users_relation project if workflow_role_ids.empty?

      # Intersect assignable roles with workflow roles
      final_role_ids = role_ids & workflow_role_ids
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION if final_role_ids.empty?

      # Use SQL subquery to avoid DISTINCT + ORDER BY problems
      subquery = Principal.active
                          .joins(members: :roles)
                          .where(type: assignable_principal_types,
                                 members: { project_id: project.id },
                                 roles: { id: final_role_ids })
                          .distinct
                          .select(:id)

      Principal.active
               .where(id: subquery)
               .order(:lastname, :firstname)
    end

    # Array-based implementation for Issue assignable users (with tracker support)
    # @param project [Project] The project to get assignable users for
    # @param tracker [Tracker, nil] Optional tracker for workflow filtering
    # @return [Array<User>] Array of assignable users
    def issue_assignable_users(project, tracker: nil)
      return [] unless project

      # Start with basic project assignable users for issues
      users = project_assignable_users project
      return users unless tracker && defined?(WorkflowTransition)

      # Get all workflow role IDs for this tracker in a single query (instead of N+1)
      workflow_role_ids = WorkflowTransition
                          .where(tracker_id: tracker.id)
                          .distinct
                          .pluck(:role_id)

      return users if workflow_role_ids.empty?

      # Get principal-role mappings for all users/groups in a single query (instead of N+1)
      principal_ids = users.map(&:id)
      principals_with_workflow_roles = Member
                                       .joins(:roles)
                                       .where(project_id: project.id,
                                              user_id: principal_ids,
                                              roles: { id: workflow_role_ids })
                                       .distinct
                                       .pluck(:user_id)
                                       .to_set

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

      # Use centralized hidden roles filter
      role_ids = filter_visible_role_ids log_time_role_ids, project: project
      return [] if role_ids.empty?

      # Single optimized query to get all users with log_time permission
      users = User.joins(members: :roles)
                  .where(members: { project_id: project.id },
                         roles: { id: role_ids },
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
      # Use centralized helper for visible assignable role IDs (global context)
      role_ids = visible_assignable_role_ids project: nil
      return [] if role_ids.empty?

      users = Principal.active
                       .joins(members: :roles)
                       .where(type: assignable_principal_types, roles: { id: role_ids })
                       .distinct
                       .to_a

      # Add current user if logged and has assignable roles globally
      if User.current.logged? && users.exclude?(User.current)
        user_has_assignable_roles = User.current.members.joins(:roles).exists?(roles: { id: role_ids })
        users << User.current if user_has_assignable_roles
      end

      users.uniq!
      users.sort
    end

    # Multi-project assignable users returning ActiveRecord::Relation
    # Used by plugins that need assignable users across multiple projects (e.g., cross-project queries)
    #
    # @param project_ids [Array<Integer>] The project IDs to get assignable users for
    # @param search [String, nil] Optional search term for filtering by name
    # @param limit [Integer, nil] Optional limit for results
    # @return [ActiveRecord::Relation] Relation of assignable users
    def multi_project_assignable_users_relation(project_ids, search: nil, limit: nil)
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION if project_ids.blank?

      # Use centralized helper for visible assignable role IDs (global context for multi-project)
      role_ids = visible_assignable_role_ids project: nil
      return Principal.where Additionals::SQL_NO_RESULT_CONDITION if role_ids.empty?

      # Use SQL subquery to avoid DISTINCT + ORDER BY problems
      subquery = Principal.active
                          .joins(members: :roles)
                          .where(type: assignable_principal_types,
                                 members: { project_id: project_ids },
                                 roles: { id: role_ids })
                          .distinct
                          .select(:id)

      scope = Principal.active
                       .where(id: subquery)
                       .order(:lastname, :firstname)

      scope = scope.like(search) if search.present?
      scope = scope.limit(limit) if limit.present?
      scope
    end

    # Returns IDs of users who are assignable and visible to current user
    # Used to filter user IDs against visible roles (e.g., for recently assigned users from journals)
    #
    # @param project_ids [Array<Integer>] The project IDs to check
    # @return [Array<Integer>] IDs of assignable and visible users
    def visible_assignable_user_ids(project_ids)
      multi_project_assignable_users_relation(project_ids).pluck(:id)
    end
  end
end
