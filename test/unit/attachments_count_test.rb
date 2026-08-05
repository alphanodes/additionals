# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AttachmentsCountTest < Additionals::TestCase
  include Redmine::I18n

  def test_attachments_count_returns_number_of_attached_files
    assert_equal 4, issues(:issues_003).attachments_count
  end

  def test_attachments_count_is_zero_without_attached_files
    assert_equal 0, issues(:issues_001).attachments_count
  end

  def test_load_attachments_count_preloads_counts_including_zero
    entries = [issues(:issues_001), issues(:issues_003), issues(:issues_014)]

    Issue.load_attachments_count entries

    assert_equal [0, 4, 6], entries.map(&:attachments_count)
  end

  # The preloaded value has to win over a fresh count, otherwise the list would
  # still run one query per row.
  def test_attachments_count_uses_preloaded_value
    issue = issues :issues_003
    Issue.load_attachments_count [issue]
    Attachment.where(container_type: 'Issue', container_id: issue.id).delete_all

    assert_equal 4, issue.attachments_count
  end

  def test_load_attachments_count_with_empty_collection
    assert_nil Issue.load_attachments_count([])
  end

  def test_column_sorts_by_number_of_attached_files
    column = QueryAttachmentsCountColumn.new Issue
    ids = Issue.where(id: [issues(:issues_001).id, issues(:issues_003).id, issues(:issues_014).id])
               .order(Arel.sql("#{column.sortable} DESC"))
               .ids

    assert_equal [issues(:issues_014).id, issues(:issues_003).id, issues(:issues_001).id], ids
  end

  def test_column_uses_own_caption
    column = QueryAttachmentsCountColumn.new Issue

    I18n.with_locale :en do
      assert_equal 'Number of files', column.caption
    end
  end

  def test_filter_selects_entries_with_at_least_the_given_amount
    ids = issue_ids_for '>=', ['4']

    assert_includes ids, issues(:issues_003).id
    assert_includes ids, issues(:issues_014).id
    assert_not_includes ids, issues(:issues_002).id
  end

  def test_filter_selects_entries_without_attached_files
    ids = issue_ids_for '=', ['0']

    assert_includes ids, issues(:issues_001).id
    assert_not_includes ids, issues(:issues_003).id
  end

  private

  # IssueQuery only gains the query concern through a dependent plugin, so the
  # concern is mixed into the instance here - the way a plugin query class gets
  # it - to keep the test running on additionals alone.
  def issue_ids_for(operator, values)
    query = IssueQuery.new name: '_'
    query.extend Additionals::Concerns::Query::InstanceMethods
    sql = query.send :sql_for_attachments_count_field, 'attachments_count', operator, values

    Issue.where(sql).ids
  end
end
