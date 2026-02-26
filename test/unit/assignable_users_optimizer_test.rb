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

    # Create sufficient test data to detect N+1 problems (minimum 10 assignable users)
    assignable_role = Role.create!(
      name: 'Performance Test Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    # Create 10 additional users to have enough data for N+1 detection
    created_users = []
    10.times do |i|
      user = User.create!(
        login: "perftest#{i}",
        firstname: "PerfTest#{i}",
        lastname: 'User',
        mail: "perftest#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      created_users << user
      Member.create! project: project, principal: user, roles: [assignable_role]
    end

    # Test that project_assignable_users doesn't cause N+1 queries
    # With 10+ assignable users, N+1 problem would show significantly more queries
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.project_assignable_users project
    end

    # Should use limited number of queries (not N+1)
    # With N+1 problem, this would be 20+ queries (2 per user)
    assert_operator queries_before, :<=, 10, 'project_assignable_users should use limited number of queries'

    # Verify we actually have enough test data
    assignable_users = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_operator assignable_users.size, :>=, 10, 'Should have at least 10 assignable users for valid N+1 test'
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

    # Create sufficient test data to detect N+1 problems (minimum 10 users with log_time permission)
    log_time_role = Role.create!(
      name: 'Log Time Performance Role',
      assignable: true,
      permissions: %i[view_issues log_time]
    )

    # Create 10 additional users with log_time permission
    created_users = []
    10.times do |i|
      user = User.create!(
        login: "logtimeperf#{i}",
        firstname: "LogTimePerf#{i}",
        lastname: 'User',
        mail: "logtimeperf#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      created_users << user
      Member.create! project: project, principal: user, roles: [log_time_role]
    end

    # Test that log_time_assignable_users doesn't cause N+1 queries
    # With 10+ users with log_time permission, N+1 problem would show significantly more queries
    queries_before = count_sql_queries do
      Additionals::AssignableUsersOptimizer.log_time_assignable_users project
    end

    # Should use limited number of queries (not N+1)
    # With N+1 problem, this would be 20+ queries (2 per user)
    assert_operator queries_before, :<=, 10, 'log_time_assignable_users should use limited number of queries'

    # Verify we actually have enough test data
    log_time_users = Additionals::AssignableUsersOptimizer.log_time_assignable_users project

    assert_operator log_time_users.size, :>=, 10, 'Should have at least 10 users with log_time permission for valid N+1 test'
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
      users = assignable.grep User
      groups = assignable.grep Group

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

  def test_multi_project_assignable_users_relation_returns_relation
    project1 = projects :projects_001
    project2 = projects :projects_002

    result = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation [project1.id, project2.id]

    assert_kind_of ActiveRecord::Relation, result
  end

  def test_multi_project_assignable_users_relation_with_empty_project_ids
    result = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation []

    assert_kind_of ActiveRecord::Relation, result
    assert_empty result.to_a
  end

  def test_multi_project_assignable_users_relation_with_hidden_roles
    project = projects :projects_001

    # Create a hidden role
    hidden_role = Role.create!(
      name: 'Multi Project Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create a user with the hidden role
    user = User.create!(
      login: 'multiprojecthiddenuser',
      firstname: 'MultiProjectHidden',
      lastname: 'User',
      mail: 'multiprojecthidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [hidden_role]

    # Create a regular user without show_hidden_roles permission
    regular_user = User.create!(
      login: 'multiprojectregularuser',
      firstname: 'MultiProjectRegular',
      lastname: 'User',
      mail: 'multiprojectregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    assignable = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation([project.id]).to_a

    assert_not_includes assignable, user, 'User with hidden role should not be visible to regular users'

    # Admin should see all users
    User.current = users :users_001
    assignable_admin = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation([project.id]).to_a

    assert_includes assignable_admin, user, 'Admin should see users with hidden roles'
  end

  def test_multi_project_assignable_users_relation_with_search
    project = projects :projects_001

    result = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation(
      [project.id],
      search: 'john'
    )

    assert_kind_of ActiveRecord::Relation, result
  end

  def test_multi_project_assignable_users_relation_with_limit
    project = projects :projects_001

    result = Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation(
      [project.id],
      limit: 2
    )

    assert_operator result.to_a.size, :<=, 2
  end

  def test_visible_assignable_user_ids_returns_array
    project = projects :projects_001

    result = Additionals::AssignableUsersOptimizer.visible_assignable_user_ids [project.id]

    assert_kind_of Array, result
    result.each { |id| assert_kind_of Integer, id }
  end

  def test_visible_assignable_user_ids_excludes_hidden_roles
    project = projects :projects_001

    # Create a hidden role
    hidden_role = Role.create!(
      name: 'Visible IDs Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create a user with the hidden role
    user = User.create!(
      login: 'visibleidshiddenuser',
      firstname: 'VisibleIdsHidden',
      lastname: 'User',
      mail: 'visibleidshidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [hidden_role]

    # Create a regular user without show_hidden_roles permission
    regular_user = User.create!(
      login: 'visibleidsregularuser',
      firstname: 'VisibleIdsRegular',
      lastname: 'User',
      mail: 'visibleidsregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see user IDs with hidden roles
    User.current = regular_user
    visible_ids = Additionals::AssignableUsersOptimizer.visible_assignable_user_ids [project.id]

    assert_not_includes visible_ids, user.id, 'User ID with hidden role should not be visible to regular users'

    # Admin should see all user IDs
    User.current = users :users_001
    visible_ids_admin = Additionals::AssignableUsersOptimizer.visible_assignable_user_ids [project.id]

    assert_includes visible_ids_admin, user.id, 'Admin should see user IDs with hidden roles'
  end

  # Additional tests for hidden roles across all methods

  def test_project_assignable_users_relation_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Relation Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    hidden_user = User.create!(
      login: 'relationhiddenuser',
      firstname: 'RelationHidden',
      lastname: 'User',
      mail: 'relationhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'relationregularuser',
      firstname: 'RelationRegular',
      lastname: 'User',
      mail: 'relationregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.project_assignable_users_relation(project).to_a

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible via relation to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.project_assignable_users_relation(project).to_a

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles via relation'
  end

  def test_issue_assignable_users_relation_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Issue Relation Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    hidden_user = User.create!(
      login: 'issuerelationhiddenuser',
      firstname: 'IssueRelationHidden',
      lastname: 'User',
      mail: 'issuerelationhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'issuerelationregularuser',
      firstname: 'IssueRelationRegular',
      lastname: 'User',
      mail: 'issuerelationregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project).to_a

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible in issue relation to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project).to_a

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles in issue relation'
  end

  def test_issue_assignable_users_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Issue Array Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    hidden_user = User.create!(
      login: 'issuearrayhiddenuser',
      firstname: 'IssueArrayHidden',
      lastname: 'User',
      mail: 'issuearrayhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'issuearrayregularuser',
      firstname: 'IssueArrayRegular',
      lastname: 'User',
      mail: 'issuearrayregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.issue_assignable_users project

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible in issue array to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.issue_assignable_users project

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles in issue array'
  end

  def test_log_time_assignable_users_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'LogTime Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues log_time]
    )

    hidden_user = User.create!(
      login: 'logtimehiddenuser',
      firstname: 'LogTimeHidden',
      lastname: 'User',
      mail: 'logtimehidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'logtimeregularuser',
      firstname: 'LogTimeRegular',
      lastname: 'User',
      mail: 'logtimeregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.log_time_assignable_users project

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible in log_time to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.log_time_assignable_users project

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles in log_time'
  end

  def test_user_with_show_hidden_roles_permission_can_see_hidden_users
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Permission Test Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    hidden_user = User.create!(
      login: 'permtesthiddenuser',
      firstname: 'PermTestHidden',
      lastname: 'User',
      mail: 'permtesthidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    # Create a role with show_hidden_roles_in_memberbox permission
    role_with_permission = Role.create!(
      name: 'Can See Hidden Roles',
      assignable: true,
      permissions: %i[view_issues show_hidden_roles_in_memberbox]
    )

    user_with_permission = User.create!(
      login: 'canseehiddenuser',
      firstname: 'CanSeeHidden',
      lastname: 'User',
      mail: 'canseehidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user_with_permission, roles: [role_with_permission]

    # User with show_hidden_roles_in_memberbox permission should see hidden users
    User.current = user_with_permission
    result = Additionals::AssignableUsersOptimizer.project_assignable_users project

    assert_includes result, hidden_user, 'User with show_hidden_roles_in_memberbox should see users with hidden roles'
  end

  def test_issue_assignable_users_relation_with_tracker_and_hidden_roles
    project = projects :projects_001
    tracker = trackers :trackers_001

    hidden_role = Role.create!(
      name: 'Tracker Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create workflow for the hidden role
    WorkflowTransition.create!(
      role_id: hidden_role.id,
      tracker_id: tracker.id,
      old_status_id: 1,
      new_status_id: 2
    )

    hidden_user = User.create!(
      login: 'trackerhiddenuser',
      firstname: 'TrackerHidden',
      lastname: 'User',
      mail: 'trackerhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'trackerregularuser',
      firstname: 'TrackerRegular',
      lastname: 'User',
      mail: 'trackerregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles even with tracker filtering
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project, tracker: tracker).to_a

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible with tracker filter to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project, tracker: tracker).to_a

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles with tracker filter'
  end

  def test_global_assignable_users_excludes_hidden_roles_for_regular_user
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Global Exclude Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    hidden_user = User.create!(
      login: 'globalexcludehiddenuser',
      firstname: 'GlobalExcludeHidden',
      lastname: 'User',
      mail: 'globalexcludehidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'globalexcluderegularuser',
      firstname: 'GlobalExcludeRegular',
      lastname: 'User',
      mail: 'globalexcluderegular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.global_assignable_users

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible globally to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.global_assignable_users

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles globally'
  end

  def test_hidden_roles_consistency_regular_user_excluded
    # This test ensures all methods consistently exclude hidden users for regular users
    project, hidden_user, regular_user = create_hidden_roles_consistency_test_data

    User.current = regular_user

    # All methods should exclude the hidden user for regular users
    assert_not_includes Additionals::AssignableUsersOptimizer.project_assignable_users(project),
                        hidden_user,
                        'project_assignable_users should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.project_assignable_users_relation(project).to_a,
                        hidden_user,
                        'project_assignable_users_relation should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.issue_assignable_users(project),
                        hidden_user,
                        'issue_assignable_users should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project).to_a,
                        hidden_user,
                        'issue_assignable_users_relation should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.log_time_assignable_users(project),
                        hidden_user,
                        'log_time_assignable_users should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation([project.id]).to_a,
                        hidden_user,
                        'multi_project_assignable_users_relation should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.visible_assignable_user_ids([project.id]),
                        hidden_user.id,
                        'visible_assignable_user_ids should exclude hidden user ID'
  end

  def test_hidden_roles_consistency_admin_included
    # This test ensures all methods consistently include hidden users for admin
    project, hidden_user, _regular_user = create_hidden_roles_consistency_test_data

    User.current = users :users_001

    assert_includes Additionals::AssignableUsersOptimizer.project_assignable_users(project),
                    hidden_user,
                    'Admin: project_assignable_users should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.project_assignable_users_relation(project).to_a,
                    hidden_user,
                    'Admin: project_assignable_users_relation should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.issue_assignable_users(project),
                    hidden_user,
                    'Admin: issue_assignable_users should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.issue_assignable_users_relation(project).to_a,
                    hidden_user,
                    'Admin: issue_assignable_users_relation should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.log_time_assignable_users(project),
                    hidden_user,
                    'Admin: log_time_assignable_users should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.multi_project_assignable_users_relation([project.id]).to_a,
                    hidden_user,
                    'Admin: multi_project_assignable_users_relation should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.visible_assignable_user_ids([project.id]),
                    hidden_user.id,
                    'Admin: visible_assignable_user_ids should include hidden user ID'
  end

  # ==========================================
  # Tests for Entity Methods (non-Issue models)
  # These methods ALWAYS include groups regardless of Setting.issue_group_assignment?
  # ==========================================

  def test_assignable_principal_types_respects_issue_group_assignment_setting
    with_settings issue_group_assignment: '1' do
      types = Additionals::AssignableUsersOptimizer.assignable_principal_types

      assert_includes types, 'User'
      assert_includes types, 'Group'
    end

    with_settings issue_group_assignment: '0' do
      types = Additionals::AssignableUsersOptimizer.assignable_principal_types

      assert_includes types, 'User'
      assert_not_includes types, 'Group', 'Groups should NOT be included when issue_group_assignment is disabled'
    end
  end

  def test_assignable_principal_types_all_always_includes_groups
    # This method should ALWAYS return both User and Group, regardless of settings
    with_settings issue_group_assignment: '1' do
      types = Additionals::AssignableUsersOptimizer.assignable_principal_types_all

      assert_includes types, 'User'
      assert_includes types, 'Group'
    end

    with_settings issue_group_assignment: '0' do
      types = Additionals::AssignableUsersOptimizer.assignable_principal_types_all

      assert_includes types, 'User'
      assert_includes types, 'Group', 'Groups should ALWAYS be included in assignable_principal_types_all'
    end
  end

  def test_project_assignable_principals_always_includes_groups
    project = projects :projects_001

    # Create a group with assignable role
    group = Group.create! lastname: 'Test Assignable Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Entity Assignable Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    # Even when issue_group_assignment is disabled, entities should include groups
    with_settings issue_group_assignment: '0' do
      principals = Additionals::AssignableUsersOptimizer.project_assignable_principals project

      users = principals.grep User
      groups = principals.grep Group

      assert users.any?, 'Should include users'
      assert groups.any?, 'Should include groups even when issue_group_assignment is disabled'
      assert_includes groups, group, 'Created group should be in assignable principals'
    end
  end

  def test_project_assignable_users_excludes_groups_when_setting_disabled
    project = projects :projects_001

    # Create a group with assignable role
    group = Group.create! lastname: 'Test Issue Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Issue Assignable Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    # When issue_group_assignment is disabled, issue methods should NOT include groups
    with_settings issue_group_assignment: '0' do
      users = Additionals::AssignableUsersOptimizer.project_assignable_users project

      users.each { |p| assert_kind_of User, p, 'Should only include users when issue_group_assignment is disabled' }
      assert_not_includes users, group, 'Group should NOT be in assignable users for issues'
    end
  end

  def test_project_assignable_principals_vs_users_difference_with_setting_disabled
    project = projects :projects_001

    # Create a group with assignable role
    group = Group.create! lastname: 'Comparison Test Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Comparison Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    with_settings issue_group_assignment: '0' do
      # For Issues: should NOT include groups
      issue_assignables = Additionals::AssignableUsersOptimizer.project_assignable_users project
      issue_groups = issue_assignables.grep Group

      # For Entities: should ALWAYS include groups
      entity_assignables = Additionals::AssignableUsersOptimizer.project_assignable_principals project
      entity_groups = entity_assignables.grep Group

      assert_empty issue_groups, 'Issue assignables should have NO groups when setting disabled'
      assert entity_groups.any?, 'Entity assignables should ALWAYS have groups'
      assert_includes entity_groups, group
    end
  end

  def test_project_assignable_principals_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Entity Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    hidden_user = User.create!(
      login: 'entityhiddenuser',
      firstname: 'EntityHidden',
      lastname: 'User',
      mail: 'entityhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'entityregularuser',
      firstname: 'EntityRegular',
      lastname: 'User',
      mail: 'entityregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.project_assignable_principals project

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible in entity principals to regular users'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.project_assignable_principals project

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles in entity principals'
  end

  def test_global_assignable_principals_always_includes_groups
    # Create a group with assignable role in some project
    project = projects :projects_001
    group = Group.create! lastname: 'Global Test Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Global Assignable Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    with_settings issue_group_assignment: '0' do
      principals = Additionals::AssignableUsersOptimizer.global_assignable_principals

      groups = principals.grep Group

      assert groups.any?, 'Global assignable principals should include groups even when issue_group_assignment is disabled'
    end
  end

  def test_global_assignable_principals_with_hidden_roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Global Entity Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    hidden_user = User.create!(
      login: 'globalentityhiddenuser',
      firstname: 'GlobalEntityHidden',
      lastname: 'User',
      mail: 'globalentityhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'globalentityregularuser',
      firstname: 'GlobalEntityRegular',
      lastname: 'User',
      mail: 'globalentityregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user should not see users with hidden roles
    User.current = regular_user
    result = Additionals::AssignableUsersOptimizer.global_assignable_principals

    assert_not_includes result, hidden_user, 'User with hidden role should not be visible in global entity principals'

    # Admin should see all users
    User.current = users :users_001
    result_admin = Additionals::AssignableUsersOptimizer.global_assignable_principals

    assert_includes result_admin, hidden_user, 'Admin should see users with hidden roles in global entity principals'
  end

  def test_project_assignable_principals_returns_principals_only
    project = projects :projects_001
    principals = Additionals::AssignableUsersOptimizer.project_assignable_principals project

    assert_kind_of Array, principals
    principals.each do |principal|
      assert_kind_of Principal, principal, 'project_assignable_principals should return only Principal objects'
      assert_equal Principal::STATUS_ACTIVE, principal.status, 'Should return only active principals'
    end
  end

  def test_project_assignable_principals_empty_for_nil_project
    principals = Additionals::AssignableUsersOptimizer.project_assignable_principals nil

    assert_empty principals, 'Should return empty array for nil project'
  end

  def test_global_assignable_principals_returns_principals_only
    principals = Additionals::AssignableUsersOptimizer.global_assignable_principals

    assert_kind_of Array, principals
    principals.each do |principal|
      assert_kind_of Principal, principal, 'global_assignable_principals should return only Principal objects'
    end
  end

  def test_project_assignable_principals_includes_current_user
    project = projects :projects_001
    User.current = users :users_002

    # Ensure current user has view_issues permission
    assert User.current.allowed_to?(:view_issues, project), 'Current user should have view_issues permission'

    principals = Additionals::AssignableUsersOptimizer.project_assignable_principals project

    assert_includes principals, User.current, 'Current user should be in assignable principals'
  end

  def test_entity_methods_consistency_with_hidden_roles
    # This test ensures all entity methods consistently handle hidden roles
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Entity Consistency Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    hidden_user = User.create!(
      login: 'entityconsistencyhiddenuser',
      firstname: 'EntityConsistencyHidden',
      lastname: 'User',
      mail: 'entityconsistencyhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'entityconsistencyregularuser',
      firstname: 'EntityConsistencyRegular',
      lastname: 'User',
      mail: 'entityconsistencyregular@example.com',
      status: User::STATUS_ACTIVE
    )

    # Regular user - hidden user should be excluded
    User.current = regular_user

    assert_not_includes Additionals::AssignableUsersOptimizer.project_assignable_principals(project),
                        hidden_user,
                        'Regular user: project_assignable_principals should exclude hidden user'

    assert_not_includes Additionals::AssignableUsersOptimizer.global_assignable_principals,
                        hidden_user,
                        'Regular user: global_assignable_principals should exclude hidden user'

    # Admin - hidden user should be included
    User.current = users :users_001

    assert_includes Additionals::AssignableUsersOptimizer.project_assignable_principals(project),
                    hidden_user,
                    'Admin: project_assignable_principals should include hidden user'

    assert_includes Additionals::AssignableUsersOptimizer.global_assignable_principals,
                    hidden_user,
                    'Admin: global_assignable_principals should include hidden user'
  end

  def test_project_assignable_principals_performance
    project = projects :projects_001

    # Create sufficient test data
    assignable_role = Role.create!(
      name: 'Entity Performance Test Role',
      assignable: true,
      permissions: %i[view_issues]
    )

    10.times do |i|
      user = User.create!(
        login: "entityperftest#{i}",
        firstname: "EntityPerfTest#{i}",
        lastname: 'User',
        mail: "entityperftest#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      Member.create! project: project, principal: user, roles: [assignable_role]
    end

    queries_count = count_sql_queries do
      Additionals::AssignableUsersOptimizer.project_assignable_principals project
    end

    assert_operator queries_count, :<=, 10, 'project_assignable_principals should use limited number of queries'
  end

  private

  def create_hidden_roles_consistency_test_data
    project = projects :projects_001

    hidden_role = Role.create!(
      name: 'Consistency Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues log_time]
    )

    hidden_user = User.create!(
      login: 'consistencyhiddenuser',
      firstname: 'ConsistencyHidden',
      lastname: 'User',
      mail: 'consistencyhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    regular_user = User.create!(
      login: 'consistencyregularuser',
      firstname: 'ConsistencyRegular',
      lastname: 'User',
      mail: 'consistencyregular@example.com',
      status: User::STATUS_ACTIVE
    )

    [project, hidden_user, regular_user]
  end
end
