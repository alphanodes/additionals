require File.expand_path('../../test_helper', __FILE__)

class TimeEntryTest < ActiveSupport::TestCase
  fixtures :issues, :projects, :users, :time_entries,
           :members, :roles, :member_roles,
           :trackers, :issue_statuses,
           :projects_trackers,
           :journals, :journal_details,
           :issue_categories, :enumerations,
           :groups_users,
           :enabled_modules

  def teardown
    User.current = nil
  end

  def test_create_time_entry_without_issue
    entry = TimeEntry.new(project: Project.find(1), user: User.find(1), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    assert entry.valid?
    assert entry.save
  end

  def test_create_time_entry_with_open_issue
    entry = TimeEntry.new(project: Project.find(1), user: User.find(1), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = Issue.find(7)
    assert !entry.issue.closed?
    assert entry.valid?
    assert entry.save
  end

  def test_create_time_entry_with_closed_issue_without_permission
    entry = TimeEntry.new(project: Project.find(1), user: User.find(1), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = Issue.find(8)
    assert entry.issue.closed?
    assert !entry.valid?
    assert !entry.save
  end

  def test_create_time_entry_with_closed_issue_with_permission
    User.current = User.find(3)
    role = Role.create!(name: 'Additionals Tester', permissions: [:log_time_on_closed_issues])
    Member.delete_all(user_id: User.current)
    project = Project.find(1)
    Member.create!(principal: User.current, project_id: project.id, role_ids: [role.id])

    entry = TimeEntry.new(project: Project.find(1), user: User.current, activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = Issue.find(8)
    assert entry.issue.closed?
    assert entry.valid?
    assert entry.save
  end
end
