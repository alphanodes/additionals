require File.expand_path('../../test_helper', __FILE__)

class IssueTest < ActiveSupport::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issue_categories, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
  end

  def teardown
    User.current = nil
  end

  def test_create
    issue = Issue.new(project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create')
    assert issue.save
    assert_equal issue.tracker.default_status, issue.status
    assert issue.description.nil?
  end

  def test_change_open_issue
    User.current = User.find(3)
    issue = Issue.find(7)
    issue.subject = 'Should be be saved'
    assert issue.save
  end

  def test_change_closed_issue_with_permission
    skip 'Validate needs more love to fix dependency problems'
    User.current = User.find(3)
    role = Role.create!(name: 'Additionals Tester', permissions: [:edit_closed_issues])
    Member.delete_all(user_id: User.current)
    project = Project.find(1)
    Member.create!(principal: User.current, project_id: project.id, role_ids: [role.id])

    issue = Issue.find(8)

    issue.subject = 'Should be saved'
    assert issue.save

    issue.reload
    assert_equal 'Should be saved', issue.subject
  end

  def test_change_closed_issue_without_permission
    skip 'Validate needs more love to fix dependency problems'
    User.current = User.find(3)
    issue = Issue.find(8)

    assert issue.closed?
    issue.subject = 'Should be not be saved'
    assert !issue.save
    issue.reload
    assert_not_equal 'Should be not be saved', issue.subject
  end
end
