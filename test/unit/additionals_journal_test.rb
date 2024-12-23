# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsJournalTest < Additionals::TestCase
  def setup
    prepare_tests
    @issue = issues :issues_001
    @current_journal = Journal.new journalized: @issue, user: users(:users_001), notes: ''
  end

  def test_journal_history_with_added_entries
    assert_difference 'JournalDetail.count', 2 do
      assert AdditionalsJournal.save_journal_history(@current_journal,
                                                     'issue_test_relation',
                                                     [1],
                                                     [1, 2, 3])
    end
  end

  def test_journal_history_with_removed_entries
    assert_difference 'JournalDetail.count', 2 do
      assert AdditionalsJournal.save_journal_history(@current_journal,
                                                     'issue_test_relation',
                                                     [1, 2, 3],
                                                     [1])
    end
  end

  def test_journal_history_without_changes
    assert_no_difference 'JournalDetail.count' do
      assert AdditionalsJournal.save_journal_history(@current_journal,
                                                     'issue_test_relation',
                                                     [1, 2, 3],
                                                     [1, 2, 3])
    end
  end
end
