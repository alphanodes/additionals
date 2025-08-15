# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class TimeEntryTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  def teardown
    User.current = nil
  end

  def test_create_time_entry_without_issue
    entry = TimeEntry.generate project: projects(:projects_001)

    assert entry.valid?
    assert_save entry
  end

  def test_create_time_entry_with_open_issue
    entry = TimeEntry.generate issue: issues(:issues_002)

    assert_not entry.issue.closed?
    assert entry.valid?
    assert_save entry
  end

  def test_create_time_entry_with_closed_issue_without_permission
    User.current = nil

    entry = TimeEntry.generate issue: issues(:issues_008)

    assert entry.issue.closed?
    assert_not entry.valid?
    assert_not entry.save
  end

  def test_create_time_entry_with_closed_issue_with_permission
    User.current = users :users_003
    role = Role.create! name: 'Additionals Tester', permissions: [:log_time_on_closed_issues]
    Member.where(user_id: User.current).delete_all
    project = projects :projects_001
    Member.create! principal: User.current, project_id: project.id, role_ids: [role.id]

    entry = TimeEntry.generate issue: issues(:issues_008)

    assert entry.issue.closed?
    assert entry.valid?
    assert_save entry
  end

  def test_assignable_users_performance
    project = projects :projects_001

    # Create sufficient test data to detect N+1 problems (minimum 8 users with log_time permission)
    time_entry_role = Role.create!(
      name: 'TimeEntry Performance Role',
      assignable: true,
      permissions: %i[view_issues log_time]
    )

    # Create 8 additional users with log_time permission
    created_users = []
    8.times do |i|
      user = User.create!(
        login: "timeentryperf#{i}",
        firstname: "TimeEntryPerf#{i}",
        lastname: 'User',
        mail: "timeentryperf#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      created_users << user
      Member.create! project: project, principal: user, roles: [time_entry_role]
    end

    entry = TimeEntry.generate project: project

    # Test that assignable_users doesn't cause N+1 queries
    # With 8+ users with log_time permission, N+1 problem would show significantly more queries
    queries_before = count_sql_queries { entry.assignable_users }

    # Create a new time entry for same project - should use cached/optimized query
    entry2 = TimeEntry.generate project: project
    queries_after = count_sql_queries { entry2.assignable_users }

    # Should use consistent number of queries (not N+1)
    # With N+1 problem, queries would scale with user count
    assert_operator queries_after, :<=, queries_before + 2, 'assignable_users should not cause N+1 queries'

    # Verify we actually have enough test data
    assignable_users = entry.assignable_users

    assert_operator assignable_users.size, :>=, 8, 'Should have at least 8 users with log_time permission for valid N+1 test'
  end

  def test_assignable_users_with_log_time_permission
    project = projects :projects_001
    entry = TimeEntry.generate project: project

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

    assignable = entry.assignable_users

    assert_not_includes assignable, user_without_log_time, 'User without log_time permission should not be assignable'
    assert_includes assignable, user_with_log_time, 'User with log_time permission should be assignable'
  end

  def test_assignable_users_with_hidden_roles
    project = projects :projects_001
    entry = TimeEntry.generate project: project

    # Create a hidden role with log_time permission
    hidden_role = Role.create!(
      name: 'Hidden Log Time Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: [:log_time]
    )

    # Create a user with the hidden role
    user = User.create!(
      login: 'hiddenlogtime',
      firstname: 'Hidden',
      lastname: 'LogTime',
      mail: 'hiddenlogtime@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [hidden_role]

    # Create a regular user without show_hidden_roles permission
    regular_user = User.create!(
      login: 'regulartimeuser',
      firstname: 'Regular',
      lastname: 'TimeUser',
      mail: 'regulartime@example.com',
      status: User::STATUS_ACTIVE
    )

    # Create a role without show_hidden_roles permission but with log_time
    regular_role = Role.create!(
      name: 'Regular Time Role',
      permissions: %i[view_project log_time]
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    # Regular user should not see users with hidden roles
    User.current = regular_user
    assignable = entry.assignable_users

    assert_not_includes assignable, user, 'User with hidden role should not be visible to regular users'

    # Admin should see users with hidden roles (users_001 has show_hidden_roles permission from prepare_tests)
    User.current = users :users_001
    assignable_admin = entry.assignable_users

    assert_includes assignable_admin, user, 'Admin should see users with hidden roles'
  end

  def test_assignable_users_includes_current_user
    project = projects :projects_001
    entry = TimeEntry.generate project: project
    User.current = users :users_002

    # Ensure current user has log_time permission
    assert User.current.allowed_to?(:log_time, project), 'Current user should have log_time permission'

    assignable = entry.assignable_users

    assert_includes assignable, User.current, 'Current user with log_time permission should be in assignable users'
  end

  def test_assignable_users_returns_users_only
    entry = TimeEntry.generate project: projects(:projects_001)
    assignable = entry.assignable_users

    assert_kind_of Array, assignable
    assignable.each do |user|
      assert_kind_of User, user, 'assignable_users should return only User objects'
      assert_equal User::STATUS_ACTIVE, user.status, 'assignable_users should return only active users'
    end
  end
end
