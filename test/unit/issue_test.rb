# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class IssueTest < Additionals::TestCase
  fixtures :projects, :users, :groups_users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issue_categories, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def setup
    prepare_tests
    set_language_if_valid 'en'
  end

  def teardown
    User.current = nil
  end

  def test_create
    issue = Issue.new project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create'

    assert_save issue
    assert_equal issue.tracker.default_status, issue.status
    assert_nil issue.description
  end

  def test_change_open_issue
    with_plugin_settings 'additionals', issue_freezed_with_close: 1 do
      User.current = users :users_003
      issue = issues :issues_007
      issue.subject = 'Should be be saved'

      assert_save issue
    end
  end

  def test_change_closed_issue_with_permission
    with_plugin_settings 'additionals', issue_freezed_with_close: 1 do
      User.current = users :users_003
      role = Role.create! name: 'Additionals Tester', permissions: [:edit_closed_issues]
      Member.where(user_id: User.current).delete_all
      project = projects :projects_001
      Member.create! principal: User.current, project_id: project.id, role_ids: [role.id]

      issue = issues :issues_008

      issue.subject = 'Should be saved'

      assert_save issue

      issue.reload

      assert_equal 'Should be saved', issue.subject
    end
  end

  def test_change_closed_issue_without_permission
    with_plugin_settings 'additionals', issue_freezed_with_close: 1 do
      User.current = users :users_003
      issue = issues :issues_008

      assert issue.closed?
      issue.subject = 'Should be not be saved'

      assert_not issue.save
      issue.reload

      assert_not_equal 'Should be not be saved', issue.subject

      issue.status_id = 1

      assert issue.status_was.is_closed
      assert_not issue.closed?
      assert_not issue.save
    end
  end

  def test_new_issue_should_always_be_changeable
    with_plugin_settings 'additionals', issue_freezed_with_close: 1 do
      User.current = users :users_003

      issue = Issue.generate subject: 'new issue for closing test',
                             status_id: 1

      assert_save issue

      issue = Issue.generate subject: 'new issue for closing test and closed state',
                             status_id: 5

      assert_save issue
    end
  end

  def test_change_closed_issue_without_permission_but_freezed_disabled
    with_plugin_settings 'additionals', issue_freezed_with_close: 0 do
      User.current = users :users_003
      issue = issues :issues_008

      issue.subject = 'Should be saved'

      assert_save issue

      issue.reload

      assert_equal 'Should be saved', issue.subject
    end
  end

  def test_unchanged_existing_issue_should_not_create_validation_error
    with_plugin_settings 'additionals', issue_freezed_with_close: 1 do
      User.current = users :users_003
      issue = issues :issues_008

      assert_save issue

      # but changed issues should throw error
      issue.subject = 'changed'

      assert_not issue.save
    end
  end

  def test_auto_assigned_to
    with_plugin_settings 'additionals', issue_auto_assign: 1,
                                        issue_auto_assign_status: ['1'],
                                        issue_auto_assign_role: '1' do
      issue = Issue.new project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create'

      assert_save issue
      assert_equal 2, issue.assigned_to_id
    end
  end

  def test_disabled_auto_assigned_to
    with_plugin_settings 'additionals', issue_auto_assign: 0,
                                        issue_auto_assign_status: ['1'],
                                        issue_auto_assign_role: '1' do
      issue = Issue.new project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create'

      assert_save issue
      assert_nil issue.assigned_to_id
    end

    with_plugin_settings 'additionals', issue_auto_assign: 1,
                                        issue_auto_assign_status: [],
                                        issue_auto_assign_role: '1' do
      issue = Issue.new project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create'

      assert_save issue
      assert_nil issue.assigned_to_id
    end

    with_plugin_settings 'additionals', issue_auto_assign: 1,
                                        issue_auto_assign_status: ['1'],
                                        issue_auto_assign_role: '' do
      issue = Issue.new project_id: 1, tracker_id: 1, author_id: 3, subject: 'test_create'

      assert_save issue
      assert_nil issue.assigned_to_id
    end
  end

  def test_assigned_to_should_add_watcher
    user = users :users_003
    user.pref.auto_watch_on = ['issue_assigned']
    user.pref.save
    issue = Issue.new author_id: user.id, project_id: 1, tracker_id: 1, assigned_to_id: user.id, subject: 'test_assigned_should_add_watcher'

    assert_difference 'Watcher.count', 1 do
      assert_save issue
    end
  end

  def test_assigned_to_with_group_should_not_add_watcher
    group = Group.find 10
    Member.create! project_id: 1, principal: group, role_ids: [1]

    with_settings issue_group_assignment: '1' do
      issue = Issue.new author_id: 3, project_id: 1, tracker_id: 1, assigned_to_id: group.id, subject: 'test_assigned_should_add_watcher'

      assert_no_difference 'Watcher.count' do
        assert_save issue
      end
    end
  end
end
