# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class IssuesControllerTest < Additionals::ControllerTest
  fixtures :users, :email_addresses, :roles,
           :enumerations,
           :projects, :projects_trackers, :enabled_modules,
           :members, :member_roles,
           :issues, :issue_statuses, :issue_categories, :issue_relations,
           :versions,
           :trackers,
           :workflows,
           :custom_fields, :custom_values, :custom_fields_projects, :custom_fields_trackers,
           :time_entries,
           :watchers,
           :journals, :journal_details,
           :repositories, :changesets,
           :queries

  def setup
    manager_role = roles :roles_001
    manager_role.add_permission! :edit_issue_author
  end

  test 'author field as authorized user in new with change' do
    manager_role = roles :roles_001
    manager_role.add_permission! :change_new_issue_author
    session[:user_id] = 2
    get :new,
        params: { project_id: 1 }

    assert_select '#issue_tracker_id', true
    assert_select '#issue_author_id', true
  end

  test 'author field as authorized user in new without change' do
    session[:user_id] = 2
    get :new,
        params: { project_id: 1 }

    assert_select '#issue_tracker_id', true
    assert_select '#issue_author_id', false
  end

  test 'author field as authorized user in edit' do
    session[:user_id] = 2
    get :edit,
        params: { id: 1 }

    assert_select '#issue_author_id'
  end

  test 'author field as unauthorized user in edit' do
    session[:user_id] = 3
    get :edit,
        params: { id: 1 }

    assert_select '#issue_author_id', false
  end

  test 'update author as authorized user' do
    session[:user_id] = 2

    assert_difference 'Journal.count' do
      put :update,
          params: { id: 1, issue: { author_id: 1 } }
    end
  end

  test 'update author as unauthorized user' do
    session[:user_id] = 3

    assert_no_difference 'Journal.count' do
      put :update,
          params: { id: 1, issue: { author_id: 3 } }
    end
  end

  test 'show assign-to-me on issue' do
    with_additionals_settings issue_assign_to_me: 1 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }

      assert_select 'a.assign-to-me'
    end
  end

  test 'don\'t show assign-to-me on issue without activation' do
    with_additionals_settings issue_assign_to_me: 0 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }
      assert_select 'a.assign-to-me', count: 0
    end
  end

  test 'don\'t show assign-to-me on issue with already assigned_to me' do
    with_additionals_settings issue_assign_to_me: 1 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 4 }
      assert_select 'a.assign-to-me', count: 0
    end
  end

  test 'show change status in issue sidebar' do
    with_additionals_settings issue_change_status_in_sidebar: 1 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }
      assert_select 'ul.issue-status-change-sidebar'
    end
  end

  test 'don\'t show change status in issue sidebar without activation' do
    with_additionals_settings issue_change_status_in_sidebar: 0 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }
      assert_select 'ul.issue-status-change-sidebar', count: 0
    end
  end

  test 'don\'t show forbidden status in issue sidebar without timelog' do
    with_additionals_settings(issue_change_status_in_sidebar: 1,
                              issue_timelog_required: 1,
                              issue_timelog_required_tracker: ['1'],
                              issue_timelog_required_status: ['5']) do
      @request.session[:user_id] = 2
      issue = Issue.generate! tracker_id: 1, status_id: 1
      get :show,
          params: { id: issue.id }

      assert_response :success
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-4'
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-5', count: 0
    end
  end

  test 'show forbidden status in issue sidebar if disabled' do
    with_additionals_settings(issue_change_status_in_sidebar: 1,
                              issue_timelog_required: 0,
                              issue_timelog_required_tracker: [1],
                              issue_timelog_required_status: [5]) do
      @request.session[:user_id] = 2
      issue = Issue.generate! tracker_id: 1, status_id: 1
      get :show,
          params: { id: issue.id }

      assert_response :success
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-4'
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-5'
    end
  end

  test 'show forbidden status in issue sidebar with permission issue_timelog_never_required' do
    manager_role = roles :roles_002
    manager_role.add_permission! :issue_timelog_never_required

    with_additionals_settings(issue_change_status_in_sidebar: 1,
                              issue_timelog_required: 1,
                              issue_timelog_required_tracker: [1],
                              issue_timelog_required_status: [5]) do
      @request.session[:user_id] = 2
      issue = Issue.generate! tracker_id: 1, status_id: 1
      get :show,
          params: { id: issue.id }

      assert_response :success
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-4'
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-5'
    end
  end
end
