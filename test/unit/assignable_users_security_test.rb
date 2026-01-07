# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Critical security tests for assignable_users that were missing
class AssignableUsersSecurityTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  # CRITICAL: Test for the tracker permission logic error
  def test_project_assignable_users_with_invalid_tracker_permissions
    project = projects :projects_001
    tracker = project.trackers.order(:id).first

    # This should not raise any errors
    users = project.assignable_users tracker

    assert_kind_of ActiveRecord::Relation, users
  end

  # SECURITY: Test privilege escalation through role manipulation
  def test_assignable_users_prevents_privilege_escalation
    project = projects :projects_001

    # Create a non-assignable role with dangerous permissions
    dangerous_role = Role.create!(
      name: 'Dangerous Non-Assignable Role',
      assignable: false, # NOT assignable!
      permissions: %i[manage_project_activities delete_project]
    )

    # Create user with dangerous but non-assignable role
    dangerous_user = User.create!(
      login: 'dangeroususer',
      firstname: 'Dangerous',
      lastname: 'User',
      mail: 'dangerous@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: dangerous_user, roles: [dangerous_role]

    # SECURITY CHECK: User with non-assignable role should NEVER appear in assignable_users
    assignable = project.assignable_users

    assert_not_includes assignable, dangerous_user,
                        'User with non-assignable role should never be in assignable_users - SECURITY VIOLATION!'

    # Same check for time entries
    entry = TimeEntry.generate project: project
    time_assignable = entry.assignable_users

    assert_not_includes time_assignable, dangerous_user,
                        'User with non-assignable role should never be in time entry assignable_users - SECURITY VIOLATION!'
  end

  # SECURITY: Test hidden role visibility boundary conditions
  def test_hidden_role_boundary_conditions
    project = projects :projects_001

    # Create multiple hidden roles with different permissions
    hidden_role_view = Role.create!(
      name: 'Hidden View Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: [:view_issues]
    )

    hidden_role_manage = Role.create!(
      name: 'Hidden Manage Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues manage_project_activities]
    )

    # Create users with different hidden roles
    user_view = User.create!(
      login: 'hiddenview',
      firstname: 'Hidden',
      lastname: 'View',
      mail: 'hiddenview@example.com',
      status: User::STATUS_ACTIVE
    )

    user_manage = User.create!(
      login: 'hiddenmanage',
      firstname: 'Hidden',
      lastname: 'Manage',
      mail: 'hiddenmanage@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user_view, roles: [hidden_role_view]
    Member.create! project: project, principal: user_manage, roles: [hidden_role_manage]

    # Create a truly regular user without show_hidden_roles permission
    regular_role = Role.create!(
      name: 'Regular Test Role',
      permissions: %i[view_project view_issues] # No show_hidden_roles_in_memberbox
    )

    regular_user = User.create!(
      login: 'regularuser',
      firstname: 'Regular',
      lastname: 'User',
      mail: 'regularuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    User.current = regular_user

    assignable_regular = project.assignable_users

    # SECURITY: Regular users should see NO hidden role users
    assert_not_includes assignable_regular, user_view,
                        'Regular user should not see user with hidden view role'
    assert_not_includes assignable_regular, user_manage,
                        'Regular user should not see user with hidden manage role'

    # Test admin context
    User.current = users :users_001 # Admin
    assignable_admin = project.assignable_users

    # Admin should see all assignable users including hidden roles
    assert_includes assignable_admin, user_view,
                    'Admin should see user with hidden view role'
    assert_includes assignable_admin, user_manage,
                    'Admin should see user with hidden manage role'
  end

  # PERFORMANCE: Test for the N+1 problem in global_assignable_users
  def test_global_assignable_users_n_plus_one_problem
    # This test should reveal the N+1 problem in Role.select { |role| role.allowed_to?(permission) }
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.global_assignable_users
    end

    # Should not cause N+1 queries based on number of roles
    assert_operator queries_before, :<=, 10,
                    'global_assignable_users causes N+1 queries - performance regression!'
  end

  # CONSISTENCY: Test cache invalidation scenarios
  def test_assignable_users_cache_invalidation_scenarios
    project = projects :projects_001

    # Get initial user IDs for comparison
    initial_user_ids = project.assignable_users.pluck(:id).sort

    # Add new user to project
    new_user = User.create!(
      login: 'newassignable',
      firstname: 'New',
      lastname: 'Assignable',
      mail: 'newassignable@example.com',
      status: User::STATUS_ACTIVE
    )

    # Need to use a role that has assignable: true
    assignable_role = roles :roles_001 # Manager role should be assignable
    Member.create! project: project, principal: new_user, roles: [assignable_role]

    # NOTE: No longer using cache due to ActiveRecord::Relation compatibility
    # New users should immediately appear in assignable_users
    fresh_user_ids = project.assignable_users.pluck(:id).sort

    assert_not_equal initial_user_ids, fresh_user_ids,
                     'New users should immediately appear in assignable_users!'
    assert_includes fresh_user_ids, new_user.id,
                    'New assignable user ID should appear immediately'
  end

  # EDGE CASE: Test with inactive projects
  def test_assignable_users_with_inactive_project_members
    project = projects :projects_001

    # Create user and make them inactive
    user = User.create!(
      login: 'soontobeactive',
      firstname: 'Soon',
      lastname: 'Active',
      mail: 'soonactive@example.com',
      status: User::STATUS_REGISTERED # Inactive status
    )

    assignable_role = roles :roles_002
    Member.create! project: project, principal: user, roles: [assignable_role]

    # Inactive users should not appear
    assignable = project.assignable_users

    assert_not_includes assignable, user,
                        'Inactive user should not be in assignable_users'

    # Activate user
    user.update! status: User::STATUS_ACTIVE

    # Should appear after activation (if cache is properly invalidated)
    project.reload # Force fresh query
    assignable_after = project.assignable_users

    assert_includes assignable_after, user,
                    'Newly activated user should appear in assignable_users'
  end

  # CONSISTENCY: Test cross-method consistency
  def test_project_vs_time_entry_assignable_users_consistency
    project = projects :projects_001
    entry = TimeEntry.generate project: project

    project_users = project.assignable_users
    time_users = entry.assignable_users

    # Users from time entries should be subset of project users
    # (time entries have stricter log_time permission requirements)
    # and all time assignable users should have log_time permission
    time_users.each do |user|
      assert_includes project_users, user,
                      "Time entry assignable user #{user.login} should also be in project assignable users"
      assert user.allowed_to?(:log_time, project),
             "User #{user.login} in time assignable_users should have log_time permission"
    end
  end

  # REGRESSION: Test the original N+1 scenario that started this optimization
  def test_original_timelog_controller_scenario
    project = projects :projects_001

    # Simulate the original timelog controller 'new' action scenario
    # This should not cause N+1 queries anymore
    queries = count_sql_queries do
      # Simulate what timelog controller does
      users = project.assignable_users
      users.each(&:name) # Access user attributes like the controller would
    end

    # Should be much better than the original N+1 problem
    assert_operator queries, :<=, 10,
                    'Original timelog controller N+1 scenario should be optimized'
  end
end
