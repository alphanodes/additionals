# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WatchersControllerTest < Additionals::ControllerTest
  tests IssuesController

  def setup
    @project = projects :projects_001

    @hidden_role = Role.create!(
      name: 'Watcher Hidden Role',
      hide: true,
      permissions: %i[view_issues view_project]
    )

    @hidden_user = User.create!(
      login: 'watcherhiddenuser',
      firstname: 'Hidden',
      lastname: 'Watcher',
      mail: 'watcherhiddenuser@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: @project, principal: @hidden_user, roles: [@hidden_role]
  end

  def test_watchers_list_should_hide_members_with_hidden_roles
    viewer = create_viewer_user permissions: %i[view_issues view_issue_watchers view_project]
    issue = issues :issues_001
    Watcher.create! watchable: issue, user: @hidden_user
    Watcher.create! watchable: issue, user: viewer

    @request.session[:user_id] = viewer.id

    get :show, params: { id: issue.id }

    assert_response :success
    assert_select 'ul.watchers' do
      assert_select "li.user-#{viewer.id}", 1, 'Visible watcher should be shown'
      assert_select "li.user-#{@hidden_user.id}", 0, 'Hidden role watcher should not be shown'
    end
  end

  def test_watchers_list_should_show_hidden_role_members_to_admin
    issue = issues :issues_001
    Watcher.create! watchable: issue, user: @hidden_user

    @request.session[:user_id] = users(:users_001).id

    get :show, params: { id: issue.id }

    assert_response :success
    assert_select 'ul.watchers' do
      assert_select "li.user-#{@hidden_user.id}", 1, 'Admin should see hidden role watcher'
    end
  end

  def test_watchers_list_should_show_hidden_role_members_with_permission
    viewer = create_viewer_user permissions: %i[view_issues view_issue_watchers view_project show_hidden_roles_in_memberbox]
    issue = issues :issues_001
    Watcher.create! watchable: issue, user: @hidden_user
    Watcher.create! watchable: issue, user: viewer

    @request.session[:user_id] = viewer.id

    get :show, params: { id: issue.id }

    assert_response :success
    assert_select 'ul.watchers' do
      assert_select "li.user-#{@hidden_user.id}", 1,
                    'User with show_hidden_roles_in_memberbox should see hidden role watcher'
    end
  end

  private

  def create_viewer_user(permissions:)
    role = Role.create!(
      name: "Viewer Role #{SecureRandom.hex 4}",
      permissions: permissions,
      users_visibility: 'members_of_visible_projects'
    )

    user = User.create!(
      login: "viewer#{SecureRandom.hex 4}",
      firstname: 'Viewer',
      lastname: 'User',
      mail: "viewer#{SecureRandom.hex 4}@example.com",
      status: User::STATUS_ACTIVE
    )

    Member.create! project: @project, principal: user, roles: [role]
    user
  end
end
