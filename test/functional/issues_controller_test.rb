# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class IssuesControllerTest < Additionals::ControllerTest
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

  test 'show change status in issue sidebar' do
    with_plugin_settings 'additionals', issue_change_status_in_sidebar: 1 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }

      assert_select 'ul.issue-status-change-sidebar'
    end
  end

  test 'don\'t show change status in issue sidebar without activation' do
    with_plugin_settings 'additionals', issue_change_status_in_sidebar: 0 do
      @request.session[:user_id] = 2
      get :show,
          params: { id: 2 }

      assert_select 'ul.issue-status-change-sidebar', count: 0
    end
  end

  test 'don\'t show forbidden status in issue sidebar without timelog' do
    with_plugin_settings 'additionals', issue_change_status_in_sidebar: 1,
                                        issue_timelog_required: 1,
                                        issue_timelog_required_tracker: ['1'],
                                        issue_timelog_required_status: ['5'] do
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
    with_plugin_settings 'additionals', issue_change_status_in_sidebar: 1,
                                        issue_timelog_required: 0,
                                        issue_timelog_required_tracker: [1],
                                        issue_timelog_required_status: [5] do
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

    with_plugin_settings 'additionals', issue_change_status_in_sidebar: 1,
                                        issue_timelog_required: 1,
                                        issue_timelog_required_tracker: [1],
                                        issue_timelog_required_status: [5] do
      @request.session[:user_id] = 2
      issue = Issue.generate! tracker_id: 1, status_id: 1
      get :show,
          params: { id: issue.id }

      assert_response :success
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-4'
      assert_select 'ul.issue-status-change-sidebar a.status-switch.status-5'
    end
  end

  def test_new_should_have_new_ticket_message
    with_plugin_settings 'additionals', new_ticket_message: 'blub' do
      @request.session[:user_id] = 2
      get :new, params: { project_id: 1 }

      assert_select '.new-ticket-message'
    end
  end

  def test_new_should_not_have_new_ticket_message_if_disabled_in_project
    project = projects :projects_001
    project.enable_new_ticket_message = 0

    assert_save project

    with_plugin_settings 'additionals', new_ticket_message: 'blub' do
      @request.session[:user_id] = 2
      get :new, params: { project_id: 1 }

      assert_select '.new-ticket-message', count: 0
    end
  end

  def test_show_author_badge
    with_plugin_settings 'additionals', issue_note_with_author: 1 do
      get :show, params: { id: 1 }

      assert_response :success
      assert_select '#tab-content-history #note-1 .badge-author', count: 0
      assert_select '#tab-content-history #note-2 .badge-author'
    end
  end

  def test_do_not_show_author_badge_if_disabled
    with_plugin_settings 'additionals', issue_note_with_author: 0 do
      get :show, params: { id: 1 }

      assert_response :success
      assert_select 'h4.note-header .badge-author', count: 0
    end
  end

  def test_show_attachments
    with_plugin_settings 'additionals', issue_hide_max_attachments: 10 do
      get :show, params: { id: 3 }

      assert_response :success
      assert_select 'fieldset.hide-attachments', count: 0
    end
  end

  def test_show_attachments_as_hidden
    with_plugin_settings 'additionals', issue_hide_max_attachments: 0 do
      get :show, params: { id: 3 }

      assert_response :success
      assert_select 'fieldset.hide-attachments', count: 1
    end
  end
end
