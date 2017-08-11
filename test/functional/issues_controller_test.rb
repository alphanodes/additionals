require File.expand_path('../../test_helper', __FILE__)

class IssuesControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules, :issues, :users, :members,
           :member_roles, :roles, :documents, :attachments, :news,
           :tokens, :journals, :journal_details, :changesets,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :messages, :boards, :repositories, :wikis, :wiki_pages,
           :wiki_contents, :wiki_content_versions, :versions, :comments

  def setup
    manager_role = Role.find(1)
    manager_role.add_permission!(:edit_issue_author)
  end

  test 'author field as authorized user in new with change' do
    manager_role = Role.find(1)
    manager_role.add_permission!(:change_new_issue_author)
    session[:user_id] = 2
    get :new, project_id: 1

    assert_select '#issue_tracker_id', true
    assert_select '#issue_author_id', true
  end

  test 'author field as authorized user in new without change' do
    session[:user_id] = 2
    get :new, project_id: 1

    assert_select '#issue_tracker_id', true
    assert_select '#issue_author_id', false
  end

  test 'author field as authorized user in edit' do
    session[:user_id] = 2
    get :edit, id: 1

    assert_select '#issue_author_id'
  end

  test 'author field as unauthorized user in edit' do
    session[:user_id] = 3
    get :edit, id: 1

    assert_select '#issue_author_id', false
  end

  test 'update author as authorized user' do
    session[:user_id] = 2

    assert_difference('Journal.count') do
      put :update, id: 1, issue: { author_id: 1 }
    end
  end

  test 'update author as unauthorized user' do
    session[:user_id] = 3

    assert_no_difference('Journal.count') do
      put :update, id: 1, issue: { author_id: 3 }
    end
  end
end
