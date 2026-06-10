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

  def test_add_system_note_returns_false_for_non_journalized_entity
    entity = 'not journalizable'

    assert_not AdditionalsJournal.add_system_note(entity, 'a note')
  end

  def test_add_system_note_persists_note_and_returns_true
    assert_difference 'Journal.count' do
      assert AdditionalsJournal.add_system_note(@issue, 'system note', user: users(:users_001))
    end
  end

  def test_add_system_note_returns_false_on_invalid_record
    @issue.subject = ''

    assert_no_difference 'Journal.count' do
      assert_not AdditionalsJournal.add_system_note(@issue, 'system note', user: users(:users_001))
    end
  end
end
