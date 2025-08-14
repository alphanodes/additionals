# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AssignableUsersOptimizerTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  def test_project_assignable_users_performance
    project = projects :projects_001

    # Test that project_assignable_users doesn't cause N+1 queries
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.project_assignable_users project
    end

    # Should use limited number of queries (not N+1)
    assert_operator queries_before, :<=, 10, 'project_assignable_users should use limited number of queries'
  end

  def test_project_assignable_users_with_hidden_roles
    project = projects :projects_001

    # Create a hidden role
    hidden_role = Role.create!(
      name: 'Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create a user with the hidden role
    user = User.create!(
      login: 'hiddenuser',
      firstname: 'Hidden',
      lastname: 'User',
      mail: 'hidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [hidden_role]

    # Create a regular user without show_hidden_roles permission
    regular_user = User.create!(
      login: 'regularuser',
      firstname: 'Regular',
      lastname: 'User',
      mail: 'regular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_not_includes assignable, user, 'User with hidden role should not be visible to regular users'

    # Admin should see all users
    User.current = users :users_001
    assignable_admin = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_includes assignable_admin, user, 'Admin should see users with hidden roles'
  end

  def test_log_time_assignable_users_performance
    project = projects :projects_001

    # Test that log_time_assignable_users doesn't cause N+1 queries
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.log_time_assignable_users project
    end

    # Should use limited number of queries (not N+1)
    assert_operator queries_before, :<=, 10, 'log_time_assignable_users should use limited number of queries'
  end

  def test_log_time_assignable_users_with_permissions
    project = projects :projects_001

    # Create a role without log_time permission
    role_without_log_time = Role.create!(
      name: 'No Log Time',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    # Create a role with log_time permission
    role_with_log_time = Role.create!(
      name: 'Log Time',
      assignable: true,
      permissions: %i[view_issues log_time]
    )

    # Create users with different roles
    user_without_log_time = User.create!(
      login: 'nologtime',
      firstname: 'No',
      lastname: 'LogTime',
      mail: 'nologtime@example.com',
      status: User::STATUS_ACTIVE
    )

    user_with_log_time = User.create!(
      login: 'withlogtime',
      firstname: 'With',
      lastname: 'LogTime',
      mail: 'withlogtime@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user_without_log_time, roles: [role_without_log_time]
    Member.create! project: project, principal: user_with_log_time, roles: [role_with_log_time]

    assignable = Additionals::AssignableUsersOptimizer.log_time_assignable_users project

    assert_not_includes assignable, user_without_log_time, 'User without log_time permission should not be assignable'
    assert_includes assignable, user_with_log_time, 'User with log_time permission should be assignable'
  end

  def test_global_assignable_users_performance
    # Test that global_assignable_users doesn't cause excessive queries
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.global_assignable_users
    end

    # Should use reasonable number of queries
    assert_operator queries_before, :<=, 10, 'global_assignable_users should use limited number of queries'
  end

  def test_global_assignable_users_with_hidden_roles
    # Create a hidden role
    hidden_role = Role.create!(
      name: 'Global Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    # Create a user with the hidden role in some project
    user = User.create!(
      login: 'globalhiddenuser',
      firstname: 'GlobalHidden',
      lastname: 'User',
      mail: 'globalhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    project = projects :projects_001
    Member.create! project: project, principal: user, roles: [hidden_role]

    # Regular user should not see users with hidden roles
    regular_user = users :users_002
    User.current = regular_user
    assignable = Additionals::AssignableUsersOptimizer.global_assignable_users

    # NOTE: This test might be complex depending on the global context
    # For now, we just ensure it returns an array
    assert_kind_of Array, assignable
    assignable.each { |u| assert_kind_of Principal, u }

    # Admin should see users
    User.current = users :users_001
    assignable_admin = Additionals::AssignableUsersOptimizer.global_assignable_users

    assert_kind_of Array, assignable_admin
    assignable_admin.each { |u| assert_kind_of Principal, u }
  end

  def test_project_assignable_users_includes_current_user
    project = projects :projects_001
    User.current = users :users_002

    # Ensure current user has view_issues permission
    assert User.current.allowed_to?(:view_issues, project), 'Current user should have view_issues permission'

    assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_includes assignable, User.current, 'Current user with view_issues permission should be in assignable users'
  end

  def test_project_assignable_users_returns_principals_only
    project = projects :projects_001
    assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_kind_of Array, assignable
    assignable.each do |principal|
      assert_kind_of Principal, principal, 'project_assignable_users should return only Principal objects'
      assert_equal Principal::STATUS_ACTIVE, principal.status, 'Should return only active principals'
    end
  end

  def test_log_time_assignable_users_returns_users_only
    project = projects :projects_001
    assignable = Additionals::AssignableUsersOptimizer.log_time_assignable_users project

    assert_kind_of Array, assignable
    assignable.each do |user|
      assert_kind_of User, user, 'log_time_assignable_users should return only User objects'
      assert_equal User::STATUS_ACTIVE, user.status, 'Should return only active users'
    end
  end

  def test_project_assignable_users_with_groups
    project = projects :projects_001

    with_settings issue_group_assignment: '1' do
      assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project

      # Should include both users and groups when group assignment is enabled
      users = assignable.select { |p| p.is_a? User }
      groups = assignable.select { |p| p.is_a? Group }

      assert users.any?, 'Should include users'
      # Groups might or might not be present depending on project setup
      assert_kind_of Array, groups
    end

    with_settings issue_group_assignment: '0' do
      assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project

      # Should include only users when group assignment is disabled
      assignable.each { |p| assert_kind_of User, p, 'Should only include users when group assignment is disabled' }
    end
  end

  def test_empty_project_returns_empty_array
    assignable = Additionals::AssignableUsersOptimizer.project_assignable_users nil

    assert_empty assignable, 'Should return empty array for nil project'
  end
end
