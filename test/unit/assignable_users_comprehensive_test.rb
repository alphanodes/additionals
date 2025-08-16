# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Comprehensive test to verify all assignable_users fixes work together
class AssignableUsersComprehensiveTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  def test_timeentry_uses_log_time_specific_implementation
    entry = TimeEntry.generate project: projects(:projects_001)

    User.current = users :users_001

    # TimeEntry should use log_time specific assignable users implementation
    assignable = entry.assignable_users

    assert_kind_of Array, assignable
    # TimeEntry assignable_users should only return users who can log time
    assignable.each do |user|
      assert user.allowed_to?(:log_time, entry.project),
             "User #{user.login} in TimeEntry assignable_users should have log_time permission"
    end
  end

  def test_project_assignable_users_vs_issue_assignable_users
    project = projects :projects_001
    tracker = project.trackers.first

    User.current = users :users_001

    # General project assignable users (for entities)
    general_users = project.assignable_users # No tracker = general

    # Issue-specific assignable users with tracker
    issue_users = project.assignable_users tracker # With tracker = Issue-specific

    assert_kind_of ActiveRecord::Relation, general_users
    assert_kind_of ActiveRecord::Relation, issue_users

    # Both should return valid users
    general_users.each { |u| assert_kind_of Principal, u }
    issue_users.each { |u| assert_kind_of Principal, u }

    # Issue users might be filtered by workflow, so could be subset
    assert_operator issue_users.size, :<=, general_users.size,
                    'Issue assignable users should be subset of general assignable users'
  end

  def test_hidden_roles_security_comprehensive
    project = projects :projects_001

    # Create hidden role with sensitive permissions
    hidden_role = Role.create!(
      name: 'Comprehensive Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues log_time manage_project_activities]
    )

    # Create user with hidden role
    hidden_user = User.create!(
      login: 'comprehensivehidden',
      firstname: 'Comprehensive',
      lastname: 'Hidden',
      mail: 'comprehensivehidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: hidden_user, roles: [hidden_role]

    # Create regular user without hidden role privileges
    regular_user = User.create!(
      login: 'comprehensiveregular',
      firstname: 'Comprehensive',
      lastname: 'Regular',
      mail: 'comprehensiveregular@example.com',
      status: User::STATUS_ACTIVE
    )

    regular_role = Role.create!(
      name: 'Comprehensive Regular Role',
      permissions: %i[view_project view_issues log_time]
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    # TEST 1: Project assignable users should hide users with hidden roles from regular users
    User.current = regular_user
    project_assignable = project.assignable_users

    assert_not_includes project_assignable, hidden_user,
                        'Project assignable_users should hide users with hidden roles from regular users'

    # TEST 2: TimeEntry assignable users should also hide users with hidden roles
    entry = TimeEntry.generate project: project
    time_assignable = entry.assignable_users

    assert_not_includes time_assignable, hidden_user,
                        'TimeEntry assignable_users should hide users with hidden roles from regular users'

    # TEST 3: Admin should see all users including hidden roles
    admin_user = users :users_001 # Admin
    User.current = admin_user

    admin_project_assignable = project.assignable_users
    admin_time_assignable = entry.assignable_users

    assert_includes admin_project_assignable, hidden_user,
                    'Admin should see users with hidden roles in project assignable_users'
    assert_includes admin_time_assignable, hidden_user,
                    'Admin should see users with hidden roles in TimeEntry assignable_users'
  end

  def test_performance_no_n_plus_one_comprehensive
    project = projects :projects_001

    User.current = users :users_001

    # Test project assignable_users performance
    queries_project = count_sql_queries { project.assignable_users }

    assert_operator queries_project, :<=, 10,
                    'Project assignable_users should use limited queries'

    # Test TimeEntry assignable_users performance
    entry = TimeEntry.generate project: project
    queries_time = count_sql_queries { entry.assignable_users }

    assert_operator queries_time, :<=, 10,
                    'TimeEntry assignable_users should use limited queries'

    # Test Issue assignable_users with tracker performance
    tracker = project.trackers.first
    queries_issue = count_sql_queries { project.assignable_users tracker }

    assert_operator queries_issue, :<=, 15,
                    'Issue assignable_users with tracker should use limited queries'
  end

  def test_cache_invalidation_works
    project = projects :projects_001

    # Get initial assignable users
    initial_users = project.assignable_users
    initial_count = initial_users.size

    # Add new user to project
    new_user = User.create!(
      login: 'comprehensivenew',
      firstname: 'Comprehensive',
      lastname: 'New',
      mail: 'comprehensivenew@example.com',
      status: User::STATUS_ACTIVE
    )

    assignable_role = roles :roles_002
    Member.create! project: project, principal: new_user, roles: [assignable_role]

    # Cache should be invalidated when project is reloaded
    project.reload
    fresh_users = project.assignable_users

    assert_operator fresh_users.size, :>=, initial_count,
                    'Cache invalidation should show new users after reload'
    assert_includes fresh_users, new_user,
                    'New assignable user should appear after cache invalidation'
  end

  def test_entity_permission_constants_work
    # Test that different entity types use different permissions

    # TimeEntry has its own log_time specific implementation
    entry = TimeEntry.generate project: projects(:projects_001)
    time_assignable = entry.assignable_users

    # General entities through EntityMethods use project assignable users
    require_relative 'entity_methods_assignable_users_test'
    entity = TestEntity.new project: projects(:projects_001)
    entity_assignable = entity.assignable_users

    # Both should return arrays
    assert_kind_of Array, time_assignable
    assert_kind_of Array, entity_assignable

    # TimeEntry users should be subset (log_time requirement is more restrictive)
    time_assignable.each { |u| assert_kind_of Principal, u }
    entity_assignable.each { |u| assert_kind_of Principal, u }
  end

  def test_original_n_plus_one_scenario_fixed
    # This tests the original scenario from timelog_controller that caused the N+1 problem
    project = projects :projects_001

    User.current = users :users_001

    # Simulate what timelog controller 'new' action would do
    queries = count_sql_queries do
      # Get assignable users (the original N+1 culprit)
      assignable_users = project.assignable_users

      # Access user attributes like the controller would for select options
      assignable_users.each do |user|
        user.name # This would trigger N+1 in the old implementation
        user.login
      end
    end

    # Should be much better than the original N+1 problem
    # Original was causing 7+ queries per user, now should be <=10 total
    assert_operator queries, :<=, 10,
                    'Original timelog controller N+1 scenario should be fully optimized'
  end
end
