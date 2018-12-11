require File.expand_path('../../test_helper', __FILE__)

class TimeEntryTest < Additionals::TestCase
  fixtures :issues, :projects, :users, :time_entries,
           :members, :roles, :member_roles,
           :trackers, :issue_statuses,
           :projects_trackers,
           :journals, :journal_details,
           :issue_categories, :enumerations,
           :groups_users,
           :enabled_modules

  def setup
    prepare_tests
  end

  def teardown
    User.current = nil
  end

  def test_create_time_entry_without_issue
    entry = TimeEntry.new(project: projects(:projects_001), user: users(:users_001), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    assert entry.valid?
    assert entry.save
  end

  def test_create_time_entry_with_open_issue
    entry = TimeEntry.new(project: projects(:projects_001), user: users(:users_001), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = Issue.create(project_id: 1, tracker_id: 1, author_id: 1, status_id: 1, subject: 'open issue')
    assert_not entry.issue.closed?
    assert entry.valid?
    assert entry.save
  end

  def test_create_time_entry_with_closed_issue_without_permission
    User.current = nil
    issue = Issue.generate(project_id: 1, subject: 'closed issue')
    issue.status = IssueStatus.where(is_closed: true).first
    issue.save

    entry = TimeEntry.new(project: projects(:projects_001), user: users(:users_001), activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = issue
    assert entry.issue.closed?
    assert_not entry.valid?
    assert_not entry.save
  end

  def test_create_time_entry_with_closed_issue_with_permission
    User.current = users(:users_003)
    role = Role.create!(name: 'Additionals Tester', permissions: [:log_time_on_closed_issues])
    Member.where(user_id: User.current).delete_all
    project = projects(:projects_001)
    Member.create!(principal: User.current, project_id: project.id, role_ids: [role.id])

    entry = TimeEntry.new(project: projects(:projects_001), user: User.current, activity: TimeEntryActivity.first, hours: 100)
    entry.spent_on = '2010-01-01'
    entry.issue = Issue.create(project_id: 1, tracker_id: 1, author_id: 1, status_id: 5, subject: 'closed issue')
    assert entry.issue.closed?
    assert entry.valid?
    assert entry.save
  end
end
