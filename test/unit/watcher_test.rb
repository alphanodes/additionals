# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WatcherTest < Additionals::TestCase
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :enabled_modules,
           :issues, :issue_statuses, :enumerations, :trackers, :projects_trackers,
           :boards, :messages,
           :wikis, :wiki_pages,
           :watchers

  def setup
    prepare_tests
    @author = users :users_001
    @assigned_user = users :users_002
    @changing_user = users :users_004
  end

  def test_new_issue_with_no_autowatch
    with_additionals_settings issue_autowatch_involved: 0 do
      User.current = @author
      issue = Issue.generate author_id: @author.id
      issue.save
      assert_equal 0, issue.watchers.count
      assert_not issue.watched_by?(@author)
    end
  end

  def test_new_issue_with_no_autowatch_by_user
    with_additionals_settings issue_autowatch_involved: 1 do
      User.current = @author
      User.current.pref.update_attribute :autowatch_involved_issue, false

      issue = Issue.generate author_id: @author.id
      issue.save
      assert_equal 0, issue.watchers.count
      assert_not issue.watched_by?(@author)
    end
  end

  def test_new_issue_with_author_watch_only
    with_additionals_settings issue_autowatch_involved: 1 do
      User.current = @author
      issue = Issue.generate author_id: @author.id
      issue.save
      assert_equal 1, issue.watchers.count
      assert issue.watched_by?(@author)
    end
  end

  def test_new_issue_with_author_and_assigned_to_watchers
    with_additionals_settings issue_autowatch_involved: 1 do
      User.current = @author
      issue = Issue.generate author_id: @author.id, assigned_to: @assigned_user
      issue.save

      assert_equal 2, issue.watchers.count
      assert issue.watched_by?(@author)
      assert issue.watched_by?(@assigned_user)
    end
  end

  def test_issue_do_not_add_author_with_user_change
    with_additionals_settings issue_autowatch_involved: 1 do
      User.current = @author

      issue = Issue.generate author_id: @author.id, assigned_to: @assigned_user
      issue.save
      assert_equal 2, issue.watchers.count

      issue.remove_watcher @author
      issue.reload
      assert_equal 1, issue.watchers.count

      User.current = @changing_user
      issue.subject = 'Changing....'
      issue.save

      assert_equal 2, issue.watchers.count
      assert issue.watched_by?(@changing_user)
      assert issue.watched_by?(@assigned_user)
    end
  end

  def test_issue_do_not_add_assigned_to_with_user_change
    with_additionals_settings issue_autowatch_involved: 1 do
      User.current = @author

      issue = Issue.generate author_id: @author.id, assigned_to: @assigned_user
      issue.save
      assert_equal 2, issue.watchers.count

      issue.remove_watcher @assigned_user
      issue.reload
      assert_equal 1, issue.watchers.count

      User.current = @changing_user
      issue.subject = 'Changing....'
      issue.save

      assert_equal 2, issue.watchers.count
      assert issue.watched_by?(@author)
      assert issue.watched_by?(@changing_user)
    end
  end
end
