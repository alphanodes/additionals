# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ProjectTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def test_assignable_users_amount
    with_settings issue_group_assignment: '1' do
      project = Project.find 5

      assert_equal project.assignable_users.count, project.assignable_principals.count
    end
    with_settings issue_group_assignment: '0' do
      project = Project.find 5

      assert_not_equal project.assignable_users.count, project.assignable_principals.count
    end
  end

  def test_visible_users
    project = projects :projects_005

    assert_equal 3, project.visible_users.count
  end

  def test_visible_principals
    project = projects :projects_005

    assert_equal 4, project.visible_principals.count
  end

  def test_destroy_project
    User.current = users :users_001

    @ecookbook = projects :projects_001
    # dashboards
    assert @ecookbook.dashboards.any?

    assert_difference 'Dashboard.count', -2 do
      @ecookbook.destroy
      # make sure that the project non longer exists
      assert_raise(ActiveRecord::RecordNotFound) { Project.find @ecookbook.id }
      # make sure related data was removed
      assert_nil Dashboard.where(project_id: @ecookbook.id).first
    end
  end

  def test_principals_by_role
    principals_by_role = Project.find(1).principals_by_role

    assert_kind_of Hash, principals_by_role
    role = Role.find 1

    assert_kind_of Array, principals_by_role[role]
    assert_includes principals_by_role[role], User.find(2)
  end

  def test_principals_by_role_with_hidden_role
    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role

    # User.current = User.find 2
    principals_by_role = Project.find(1).principals_by_role

    assert_equal 1, principals_by_role.count

    User.current = User.find 1
    principals_by_role = Project.find(1).principals_by_role

    assert_equal 2, principals_by_role.count
  end

  def test_active_new_ticket_message
    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      project = projects :projects_001

      assert_equal 'foo', project.active_new_ticket_message
    end
  end

  def test_active_new_ticket_message_and_disabled
    project = projects :projects_001
    project.update_attribute :enable_new_ticket_message, '0'

    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      assert_empty project.active_new_ticket_message
    end
  end

  def test_active_new_ticket_message_with_project_message
    project = projects :projects_001
    project.update_attribute :enable_new_ticket_message, '2'
    project.update_attribute :new_ticket_message, 'bar'

    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      assert_equal 'bar', project.active_new_ticket_message
    end
  end

  def test_consider_hidden_roles_without_hide_roles
    project = projects :projects_001

    assert_not project.consider_hidden_roles?
  end

  def test_consider_hidden_roles_with_hide_and_view_permission
    User.current = users :users_002
    project = projects :projects_001

    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role
    assert_not project.consider_hidden_roles?
  end

  def test_consider_hidden_roles_with_hide
    project = projects :projects_001

    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role
    assert project.consider_hidden_roles?
  end

  def test_usable_status_ids
    ids = Project.usable_status_ids

    assert_sorted_equal ids, [Project::STATUS_ACTIVE, Project::STATUS_CLOSED]
  end

  def test_sql_for_usable_status
    assert_equal "projects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status
    assert_equal "projects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status(:projects)
    assert_equal "subprojects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status('subprojects')
  end

  def test_available_status_ids
    ids = Project.available_status_ids

    assert_operator ids.count, :>, 3
  end

  def test_assignable_users_performance
    project = projects :projects_001

    # Create sufficient test data to detect N+1 problems (minimum 15 assignable users)
    project_role = Role.create!(
      name: 'Project Performance Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    # Create 15 additional users to have enough data for N+1 detection
    created_users = []
    15.times do |i|
      user = User.create!(
        login: "projectperf#{i}",
        firstname: "ProjectPerf#{i}",
        lastname: 'User',
        mail: "projectperf#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      created_users << user
      Member.create! project: project, principal: user, roles: [project_role]
    end

    # Test that assignable_users doesn't cause N+1 queries
    # With 15+ assignable users, N+1 problem would show significantly more queries
    queries_before = count_sql_queries { project.assignable_users }

    # Clear the cache and test again - should use same number of queries
    project.reload
    queries_after = count_sql_queries { project.assignable_users }

    # The optimized version should use consistent number of queries
    assert_operator queries_after, :<=, queries_before, 'assignable_users should not cause N+1 queries'
    # Should be reasonable number of queries (not N+1)
    # With N+1 problem, this would be 30+ queries (2 per user)
    assert_operator queries_after, :<=, 10, 'assignable_users should use limited number of queries'

    # Verify we actually have enough test data
    assignable_users = project.assignable_users

    assert_operator assignable_users.size, :>=, 15, 'Should have at least 15 assignable users for valid N+1 test'
  end

  def test_assignable_users_with_hidden_roles
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

    # Create a role without show_hidden_roles permission
    regular_role = Role.create!(
      name: 'Regular Role',
      permissions: %i[view_project view_issues]
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    # Regular user should not see users with hidden roles
    User.current = regular_user
    assignable = project.assignable_users

    assert_not_includes assignable, user, 'User with hidden role should not be visible to regular users'

    # Admin should see all users - use system admin (users_001 is admin: true)
    User.current = users :users_001
    project.reload # Clear any cached values
    assignable_admin = project.assignable_users

    assert_includes assignable_admin, user, 'Admin should see users with hidden roles'
  end

  def test_assignable_users_no_caching
    project = projects :projects_001

    # No longer caching due to ActiveRecord::Relation compatibility
    users1 = project.assignable_users
    users2 = project.assignable_users

    # Relations are not cached, but they should return equivalent results
    assert_equal users1.to_a, users2.to_a, 'assignable_users should return equivalent results'

    # Different tracker should return different results
    tracker = Tracker.first
    users_with_tracker = project.assignable_users tracker

    # Should return different relation objects
    assert_not_same users1, users_with_tracker, 'Different tracker should return separate relations'
  end

  def test_assignable_users_with_tracker
    project = projects :projects_001
    tracker = project.trackers.first

    users_all = project.assignable_users
    users_tracker = project.assignable_users tracker

    # Both should return relations of users
    assert_kind_of ActiveRecord::Relation, users_all
    assert_kind_of ActiveRecord::Relation, users_tracker

    # Users should all be User instances
    users_all.each { |u| assert_kind_of User, u }
    users_tracker.each { |u| assert_kind_of User, u }
  end
end
