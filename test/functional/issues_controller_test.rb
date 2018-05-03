require File.expand_path('../test_helper', __dir__)

class IssuesControllerTest < Redmine::ControllerTest
  fixtures :projects,
           :users, :email_addresses, :user_preferences,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :issue_relations,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

  def setup
    manager_role = Role.find(1)
    manager_role.add_permission!(:edit_issue_author)
  end

  test 'author field as authorized user in new with change' do
    manager_role = Role.find(1)
    manager_role.add_permission!(:change_new_issue_author)
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

    assert_difference('Journal.count') do
      put :update,
          params: { id: 1, issue: { author_id: 1 } }
    end
  end

  test 'update author as unauthorized user' do
    session[:user_id] = 3

    assert_no_difference('Journal.count') do
      put :update,
          params: { id: 1, issue: { author_id: 3 } }
    end
  end

  test 'show assign-to-me on issue' do
    Setting.plugin_additionals = ActionController::Parameters.new(
      issue_assign_to_me: 1
    )

    @request.session[:user_id] = 2
    get :show,
        params: { id: 2 }
    assert_select 'a.assign-to-me'
  end

  test 'don\'t show assign-to-me on issue without activation' do
    Setting.plugin_additionals = ActionController::Parameters.new(
      issue_assign_to_me: 0
    )

    @request.session[:user_id] = 2
    get :show,
        params: { id: 2 }
    assert_select 'a.assign-to-me', count: 0
  end

  test 'don\'t show assign-to-me on issue with already assigned_to me' do
    Setting.plugin_additionals = ActionController::Parameters.new(
      issue_assign_to_me: 1
    )

    @request.session[:user_id] = 2
    get :show,
        params: { id: 4 }
    assert_select 'a.assign-to-me', count: 0
  end

  test 'show change status in issue sidebar' do
    Setting.plugin_additionals = ActionController::Parameters.new(
      issue_change_status_in_sidebar: 1
    )

    @request.session[:user_id] = 2
    get :show,
        params: { id: 2 }
    assert_select 'ul.issue-status-change-sidebar'
  end

  test 'don\'t show change status in issue sidebar without activation' do
    Setting.plugin_additionals = ActionController::Parameters.new(
      issue_change_status_in_sidebar: 0
    )

    @request.session[:user_id] = 2
    get :show,
        params: { id: 2 }
    assert_select 'ul.issue-status-change-sidebar', count: 0
  end
end
