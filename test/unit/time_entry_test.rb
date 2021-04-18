# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class TimeEntryTest < Additionals::TestCase
  fixtures :users, :email_addresses,
           :issues, :projects, :time_entries,
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
    entry = TimeEntry.generate project: projects(:projects_001)
    assert entry.valid?
    assert_save entry
  end

  def test_create_time_entry_with_open_issue
    entry = TimeEntry.generate issue: issues(:issues_002)
    assert_not entry.issue.closed?
    assert entry.valid?
    assert_save entry
  end

  def test_create_time_entry_with_closed_issue_without_permission
    User.current = nil

    entry = TimeEntry.generate issue: issues(:issues_008)
    assert entry.issue.closed?
    assert_not entry.valid?
    assert_not entry.save
  end

  def test_create_time_entry_with_closed_issue_with_permission
    User.current = users :users_003
    role = Role.create! name: 'Additionals Tester', permissions: [:log_time_on_closed_issues]
    Member.where(user_id: User.current).delete_all
    project = projects :projects_001
    Member.create! principal: User.current, project_id: project.id, role_ids: [role.id]

    entry = TimeEntry.generate issue: issues(:issues_008)
    assert entry.issue.closed?
    assert entry.valid?
    assert_save entry
  end
end
