# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Comprehensive test for Issue assignable_users - tickets are sacred!
# This tests all critical scenarios for issue assignment
class IssueAssignableUsersComprehensiveTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  # CRITICAL: Test basic tracker-specific workflow functionality
  def test_issue_assignable_users_respects_workflow_permissions
    project = projects :projects_001
    tracker = project.trackers.first

    # Create specific workflow transition for tracker
    role = roles :roles_002
    status_from = IssueStatus.first
    status_to = IssueStatus.last

    # Create workflow transition that requires specific role
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: role.id,
      old_status_id: status_from.id,
      new_status_id: status_to.id
    )

    # Create user with workflow role
    user_with_workflow = User.create!(
      login: 'workflowuser',
      firstname: 'Workflow',
      lastname: 'User',
      mail: 'workflowuser@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user_with_workflow, roles: [role]

    # Create user without workflow role
    role_without_workflow = roles :roles_003
    user_without_workflow = User.create!(
      login: 'noworkflowuser',
      firstname: 'NoWorkflow',
      lastname: 'User',
      mail: 'noworkflowuser@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user_without_workflow, roles: [role_without_workflow]

    User.current = users :users_001

    # Test tracker-specific assignable users
    assignable = project.assignable_users tracker
    assignable_general = project.assignable_users # No tracker

    # User with workflow should be in tracker-specific list
    assert_includes assignable, user_with_workflow,
                    'User with workflow role should be assignable for tracker-specific issues'

    # Both users should be in general assignable users (no workflow filtering)
    assert_includes assignable_general, user_with_workflow,
                    'User with workflow role should be in general assignable users'
    assert_includes assignable_general, user_without_workflow,
                    'User without workflow role should still be in general assignable users'

    # Tracker-specific should be subset of general
    assert_operator assignable.size, :<=, assignable_general.size,
                    'Tracker-specific assignable users should be subset of general'
  end

  # CRITICAL: Test that issues can only be assigned to users with proper roles
  def test_issue_assignable_users_only_assignable_roles
    project = projects :projects_001
    tracker = project.trackers.first

    # Create non-assignable role
    non_assignable_role = Role.create!(
      name: 'Non-assignable Role',
      assignable: false, # CRITICAL: Not assignable!
      permissions: %i[view_issues add_issues]
    )

    # Create assignable role
    assignable_role = Role.create!(
      name: 'Assignable Role',
      assignable: true, # CRITICAL: Assignable!
      permissions: %i[view_issues add_issues]
    )

    # Create user with non-assignable role
    user_non_assignable = User.create!(
      login: 'nonassignableuser',
      firstname: 'NonAssignable',
      lastname: 'User',
      mail: 'nonassignable@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user_non_assignable, roles: [non_assignable_role]

    # Create user with assignable role
    user_assignable = User.create!(
      login: 'assignableuser',
      firstname: 'Assignable',
      lastname: 'User',
      mail: 'assignable@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user_assignable, roles: [assignable_role]

    # Add workflow transitions for assignable role so it appears in tracker-specific queries
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: assignable_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    User.current = users :users_001

    assignable = project.assignable_users tracker

    # Only user with assignable role should be in list
    assert_includes assignable, user_assignable,
                    'User with assignable role should be in assignable users'
    assert_not_includes assignable, user_non_assignable,
                        'User with non-assignable role should NOT be in assignable users'
  end

  # CRITICAL: Test hidden roles security for issue assignment
  def test_issue_assignable_users_hidden_roles_security
    project = projects :projects_001
    tracker = project.trackers.first

    # Create hidden assignable role
    hidden_role = Role.create!(
      name: 'Hidden Assignable Role',
      assignable: true,
      hide: true, # CRITICAL: Hidden role!
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues edit_issues]
    )

    # Create workflow for hidden role
    status_from = IssueStatus.first
    status_to = IssueStatus.last
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: hidden_role.id,
      old_status_id: status_from.id,
      new_status_id: status_to.id
    )

    # Create user with hidden role
    user_hidden = User.create!(
      login: 'hiddenuserissue',
      firstname: 'Hidden',
      lastname: 'IssueUser',
      mail: 'hiddenuserissue@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user_hidden, roles: [hidden_role]

    # Create regular user without show_hidden_roles permission
    regular_user = User.create!(
      login: 'regularuserissue',
      firstname: 'Regular',
      lastname: 'IssueUser',
      mail: 'regularuserissue@example.com',
      status: User::STATUS_ACTIVE
    )
    regular_role = Role.create!(
      name: 'Regular Issue Role',
      permissions: %i[view_project view_issues add_issues]
    )
    Member.create! project: project, principal: regular_user, roles: [regular_role]

    # TEST 1: Regular user should NOT see user with hidden role
    User.current = regular_user
    assignable_regular = project.assignable_users tracker

    assert_not_includes assignable_regular, user_hidden,
                        'Regular user should not see users with hidden roles in issue assignment'

    # TEST 2: Admin should see user with hidden role
    User.current = users :users_001 # Admin
    assignable_admin = project.assignable_users tracker

    assert_includes assignable_admin, user_hidden,
                    'Admin should see users with hidden roles in issue assignment'
  end

  # CRITICAL: Test that issue assignment works with group assignment setting
  def test_issue_assignable_users_with_groups
    project = projects :projects_001
    tracker = project.trackers.first

    # Create assignable role
    assignable_role = Role.create!(
      name: 'Group Assignable Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    # Create group
    group = Group.create! lastname: 'Issue Test Group'

    # Add group to project
    Member.create! project: project, principal: group, roles: [assignable_role]

    # Add workflow transition for group role so it appears in tracker-specific queries
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: assignable_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    User.current = users :users_001

    # Test with group assignment disabled
    with_settings issue_group_assignment: '0' do
      project.reload # Clear cache before testing
      assignable_no_groups = project.assignable_users tracker

      assert_not_includes assignable_no_groups, group,
                          'Groups should not be assignable when group assignment is disabled'
    end

    # Test with group assignment enabled
    with_settings issue_group_assignment: '1' do
      project.reload # Clear cache when setting changes
      assignable_with_groups = project.assignable_users tracker

      assert_includes assignable_with_groups, group,
                      'Groups should be assignable when group assignment is enabled'
    end
  end

  # CRITICAL: Test edge case - tracker without workflow transitions
  def test_issue_assignable_users_tracker_without_workflow
    project = projects :projects_001

    # Create new tracker without any workflow transitions
    tracker_no_workflow = Tracker.create!(
      name: 'No Workflow Tracker',
      default_status: IssueStatus.first,
      is_in_roadmap: true
    )
    project.trackers << tracker_no_workflow

    # Create user with assignable role
    assignable_role = Role.create!(
      name: 'No Workflow Assignable Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    user = User.create!(
      login: 'noworkflowuser2',
      firstname: 'NoWorkflow2',
      lastname: 'User',
      mail: 'noworkflowuser2@example.com',
      status: User::STATUS_ACTIVE
    )
    Member.create! project: project, principal: user, roles: [assignable_role]

    User.current = users :users_001

    # Should still return assignable users even without workflow
    assignable = project.assignable_users tracker_no_workflow
    assignable_general = project.assignable_users

    # Without workflow filtering, should return same as general
    assert_includes assignable, user, 'User should be assignable even for tracker without workflow'
    assert_equal assignable_general.sort, assignable.sort,
                 'Tracker without workflow should return same as general assignable users'
  end

  # CRITICAL: Test issue assignment after user role changes
  def test_issue_assignable_users_after_role_changes
    project = projects :projects_001
    tracker = project.trackers.first

    # Create role and user
    role = Role.create!(
      name: 'Changing Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    user = User.create!(
      login: 'changingroleuser',
      firstname: 'ChangingRole',
      lastname: 'User',
      mail: 'changingroleuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [role]

    # Create workflow for role
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    User.current = users :users_001

    # Initial state - user should be assignable
    assignable_before = project.assignable_users tracker

    assert_includes assignable_before, user, 'User should be assignable initially'

    # Remove workflow permission by changing role to non-assignable
    role.update! assignable: false

    # Clear cache and test again
    project.reload
    assignable_after = project.assignable_users tracker

    assert_not_includes assignable_after, user,
                        'User should not be assignable after role becomes non-assignable'
  end

  # CRITICAL: Test current user inclusion in issue assignment
  def test_issue_assignable_users_includes_current_user
    project = projects :projects_001
    tracker = project.trackers.first

    # Create assignable role for current user
    current_user_role = Role.create!(
      name: 'Current User Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    current_user = User.create!(
      login: 'currentusertest',
      firstname: 'CurrentUser',
      lastname: 'Test',
      mail: 'currentusertest@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: current_user, roles: [current_user_role]

    # Create workflow for current user
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: current_user_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    # Set as current user
    User.current = current_user

    assignable = project.assignable_users tracker

    assert_includes assignable, current_user,
                    'Current user should always be included in assignable users if they have proper roles'
  end

  # CRITICAL: Test issue assignment with inactive/locked users
  def test_issue_assignable_users_excludes_inactive_users
    project = projects :projects_001
    tracker = project.trackers.first

    # Create inactive user with assignable role
    assignable_role = Role.create!(
      name: 'Inactive User Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    inactive_user = User.create!(
      login: 'inactiveuserissue',
      firstname: 'Inactive',
      lastname: 'IssueUser',
      mail: 'inactiveuserissue@example.com',
      status: User::STATUS_LOCKED # CRITICAL: Inactive!
    )

    Member.create! project: project, principal: inactive_user, roles: [assignable_role]

    User.current = users :users_001

    assignable = project.assignable_users tracker

    assert_not_includes assignable, inactive_user,
                        'Inactive users should never be in assignable users list'
  end

  # CRITICAL: Test performance - no N+1 with many users and trackers
  def test_issue_assignable_users_performance_with_scale
    project = projects :projects_001

    # Create multiple trackers
    trackers = []
    3.times do |i|
      tracker = Tracker.create!(
        name: "Performance Tracker #{i}",
        default_status: IssueStatus.first,
        is_in_roadmap: true
      )
      project.trackers << tracker
      trackers << tracker
    end

    # Create multiple roles and users
    roles = []
    rusers = []
    5.times do |i|
      role = Role.create!(
        name: "Performance Role #{i}",
        assignable: true,
        permissions: %i[view_issues add_issues]
      )
      roles << role

      user = User.create!(
        login: "perfuser#{i}",
        firstname: "Perf#{i}",
        lastname: 'User',
        mail: "perfuser#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      rusers << user

      Member.create! project: project, principal: user, roles: [role]

      # Create workflows for some combinations
      trackers.each do |tracker|
        WorkflowTransition.create!(
          tracker_id: tracker.id,
          role_id: role.id,
          old_status_id: IssueStatus.first.id,
          new_status_id: IssueStatus.last.id
        )
      end
    end

    User.current = users :users_001

    # Test each tracker - should not cause N+1
    total_queries = 0
    trackers.each do |tracker|
      queries = count_sql_queries do
        assignable = project.assignable_users tracker
        # Access user attributes to trigger potential N+1
        assignable.each { |u| u.name && u.login }
      end

      total_queries += queries

      assert_operator queries, :<=, 15, "Tracker #{tracker.name} should use limited queries"
    end

    assert_operator total_queries, :<=, 45, 'Total queries should remain reasonable even with multiple trackers'
  end

  # CRITICAL: Test caching behavior is correct
  def test_issue_assignable_users_caching_correctness
    project = projects :projects_001
    tracker = project.trackers.first

    User.current = users :users_001

    # Get initial result
    assignable1 = project.assignable_users tracker
    assignable2 = project.assignable_users tracker # Should use cache

    # Results should be identical
    assert_equal assignable1, assignable2, 'Cached results should be identical'

    # Get different tracker
    other_tracker = project.trackers.second || project.trackers.create!(
      name: 'Cache Test Tracker',
      default_status: IssueStatus.first,
      is_in_roadmap: true
    )

    assignable_other = project.assignable_users other_tracker

    # Different trackers might have different results
    assert_kind_of ActiveRecord::Relation, assignable_other

    # Cache should be invalidated after reload
    project.reload
    assignable_after_reload = project.assignable_users tracker

    # Should still be correct relation
    assert_kind_of ActiveRecord::Relation, assignable_after_reload
    assignable_after_reload.each { |u| assert_kind_of Principal, u }
  end
end
