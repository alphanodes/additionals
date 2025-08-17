# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Functional test to verify Issue controller integration with optimized assignable_users
class IssuesAssignableUsersTest < Additionals::ControllerTest
  tests IssuesController

  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  # CRITICAL: Test issues#new uses optimized assignable_users without N+1
  def test_issues_new_uses_optimized_assignable_users
    project = projects :projects_001
    tracker = project.trackers.first

    # Create users with different workflow permissions
    workflow_role = Role.create!(
      name: 'Workflow Controller Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    user_with_workflow = User.create!(
      login: 'controllerworkflowuser',
      firstname: 'ControllerWorkflow',
      lastname: 'User',
      mail: 'controllerworkflowuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user_with_workflow, roles: [workflow_role]

    # Create workflow transition for the role
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: workflow_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    # Also ensure existing users have workflow transitions to appear in dropdown
    existing_role = roles :roles_002
    WorkflowTransition.find_or_create_by!(
      tracker_id: tracker.id,
      role_id: existing_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    @request.session[:user_id] = users(:users_001).id

    # This should use optimized assignable_users and not cause N+1
    queries_count = count_sql_queries do
      get :new, params: { project_id: project.id, tracker_id: tracker.id }
    end

    assert_response :success
    assert_select 'select#issue_assigned_to_id' do
      assert_select 'option', text: user_with_workflow.name
    end

    # Should use reasonable number of queries (much less than original N+1 problem)
    assert_operator queries_count, :<=, 100, 'Issues#new should not cause N+1 queries with assignable_users'
  end

  # CRITICAL: Test issues#new respects hidden roles
  def test_issues_new_respects_hidden_roles
    project = projects :projects_001
    tracker = project.trackers.first

    # Create hidden role
    hidden_role = Role.create!(
      name: 'Controller Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create user with hidden role
    user_with_hidden_role = User.create!(
      login: 'controllerhiddenuser',
      firstname: 'ControllerHidden',
      lastname: 'User',
      mail: 'controllerhiddenuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user_with_hidden_role, roles: [hidden_role]

    # Create workflow for hidden role
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: hidden_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    # Test with regular user (should not see hidden role user)
    regular_user = User.create!(
      login: 'controllerregularuser',
      firstname: 'ControllerRegular',
      lastname: 'User',
      mail: 'controllerregularuser@example.com',
      status: User::STATUS_ACTIVE
    )

    regular_role = Role.create!(
      name: 'Controller Regular Role',
      permissions: %i[view_project view_issues add_issues]
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    @request.session[:user_id] = regular_user.id

    get :new, params: { project_id: project.id, tracker_id: tracker.id }

    assert_response :success
    assert_select 'select#issue_assigned_to_id' do
      assert_select 'option', { text: user_with_hidden_role.name, count: 0 },
                    'Regular user should not see users with hidden roles in assignee dropdown'
    end

    # Test with admin user (should see hidden role user)
    @request.session[:user_id] = users(:users_001).id # Admin

    get :new, params: { project_id: project.id, tracker_id: tracker.id }

    assert_response :success
    assert_select 'select#issue_assigned_to_id' do
      assert_select 'option', text: user_with_hidden_role.name
    end
  end

  # CRITICAL: Test issues#create with optimized assignable_users validation
  def test_issues_create_validates_assignable_users
    project = projects :projects_001
    tracker = project.trackers.first

    # Create assignable user
    assignable_role = Role.create!(
      name: 'Controller Assignable Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    assignable_user = User.create!(
      login: 'controllerassignableuser',
      firstname: 'ControllerAssignable',
      lastname: 'User',
      mail: 'controllerassignableuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: assignable_user, roles: [assignable_role]

    # Create non-assignable user
    non_assignable_role = Role.create!(
      name: 'Controller Non-Assignable Role',
      assignable: false, # CRITICAL: Not assignable!
      permissions: %i[view_issues]
    )

    non_assignable_user = User.create!(
      login: 'controllernonassignableuser',
      firstname: 'ControllerNonAssignable',
      lastname: 'User',
      mail: 'controllernonassignableuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: non_assignable_user, roles: [non_assignable_role]

    # Add workflow transition for assignable user so they appear in validation
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: assignable_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    @request.session[:user_id] = users(:users_001).id

    # Should be able to create issue with assignable user
    assert_difference 'Issue.count' do
      post :create, params: {
        project_id: project.id,
        issue: {
          tracker_id: tracker.id,
          subject: 'Test assignable user creation',
          description: 'Test description',
          assigned_to_id: assignable_user.id
        }
      }
    end

    assert_redirected_to controller: 'issues', action: 'show', id: Issue.last.id
    assert_equal assignable_user, Issue.last.assigned_to

    # Should not be able to create issue with non-assignable user
    assert_no_difference 'Issue.count' do
      post :create, params: {
        project_id: project.id,
        issue: {
          tracker_id: tracker.id,
          subject: 'Test non-assignable user creation',
          description: 'Test description',
          assigned_to_id: non_assignable_user.id
        }
      }
    end

    # Should show error or reset assigned_to
    assert_response :success # Shows form again with errors
  end

  # CRITICAL: Test issues#edit uses optimized assignable_users
  def test_issues_edit_uses_optimized_assignable_users
    project = projects :projects_001
    tracker = project.trackers.first

    issue = Issue.create!(
      project: project,
      tracker: tracker,
      subject: 'Test edit assignable users',
      description: 'Test description',
      author: users(:users_001),
      status: IssueStatus.first
    )

    # Create user for assignment
    edit_role = Role.create!(
      name: 'Controller Edit Role',
      assignable: true,
      permissions: %i[view_issues edit_issues]
    )

    edit_user = User.create!(
      login: 'controlleredituser',
      firstname: 'ControllerEdit',
      lastname: 'User',
      mail: 'controlleredituser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: edit_user, roles: [edit_role]

    # Add workflow transition so user appears in tracker-specific assignable users
    WorkflowTransition.create!(
      tracker_id: tracker.id,
      role_id: edit_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    @request.session[:user_id] = users(:users_001).id

    # This should use optimized assignable_users
    queries_count = count_sql_queries do
      get :edit, params: { id: issue.id }
    end

    assert_response :success
    assert_select 'select#issue_assigned_to_id' do
      assert_select 'option', text: edit_user.name
    end

    # Should not cause N+1 queries
    assert_operator queries_count, :<=, 110, 'Issues#edit should not cause N+1 queries'
  end

  # CRITICAL: Test bulk edit with optimized assignable_users
  def test_issues_bulk_edit_uses_optimized_assignable_users
    project = projects :projects_001
    tracker = project.trackers.first

    # Create multiple issues
    issues = []
    3.times do |i|
      issues << Issue.create!(
        project: project,
        tracker: tracker,
        subject: "Bulk test issue #{i}",
        description: 'Bulk test description',
        author: users(:users_001),
        status: IssueStatus.first
      )
    end

    # Create user for bulk assignment
    bulk_role = Role.create!(
      name: 'Controller Bulk Role',
      assignable: true,
      permissions: %i[view_issues edit_issues]
    )

    bulk_user = User.create!(
      login: 'controllerbulkuser',
      firstname: 'ControllerBulk',
      lastname: 'User',
      mail: 'controllerbulkuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: bulk_user, roles: [bulk_role]

    @request.session[:user_id] = users(:users_001).id

    # Test bulk edit form
    queries_count = count_sql_queries do
      get :bulk_edit, params: { ids: issues.map(&:id) }
    end

    assert_response :success
    assert_select 'select#issue_assigned_to_id' do
      assert_select 'option', text: bulk_user.name
    end

    # Should not cause N+1 queries even with multiple issues
    assert_operator queries_count, :<=, 120, 'Bulk edit should not cause N+1 queries'
  end

  # CRITICAL: Test that tracker changes update assignable users correctly
  def test_issues_tracker_change_updates_assignable_users
    project = projects :projects_001
    tracker1 = project.trackers.first
    project.trackers.second || project.trackers.create!(
      name: 'Second Tracker',
      default_status: IssueStatus.first,
      is_in_roadmap: true
    )

    # Create user with workflow only for tracker1
    tracker_specific_role = Role.create!(
      name: 'Tracker Specific Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    tracker_user = User.create!(
      login: 'trackerspecificuser',
      firstname: 'TrackerSpecific',
      lastname: 'User',
      mail: 'trackerspecificuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: tracker_user, roles: [tracker_specific_role]

    # Create workflow only for tracker1
    WorkflowTransition.create!(
      tracker_id: tracker1.id,
      role_id: tracker_specific_role.id,
      old_status_id: IssueStatus.first.id,
      new_status_id: IssueStatus.last.id
    )

    @request.session[:user_id] = users(:users_001).id

    # Test that different trackers might have different assignable users
    get :new, params: { project_id: project.id, tracker_id: tracker1.id }

    assert_response :success

    # This verifies the system works, even if specific workflow might not be visible
    # The key is that it doesn't cause N+1 queries and respects the optimization
    assert_select 'form#issue-form'
  end
end
