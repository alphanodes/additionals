# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class CustomFieldUserFormatTest < Additionals::TestCase
  def setup
    User.current = users :users_001
    @issue = issues :issues_001
    @locked_user = User.where(status: User::STATUS_LOCKED).first
  end

  def test_scope_all_lists_every_visible_user_including_locked
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '1'

    records = field.format.possible_values_records field, @issue

    assert_equal User.visible.sorted.to_a, records.to_a
    assert_includes records, @locked_user
  end

  def test_scope_active_excludes_locked_users
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '4'

    records = field.format.possible_values_records field, @issue

    assert_equal User.active.visible.sorted.to_a, records.to_a
    assert_not_includes records, @locked_user
  end

  def test_project_scope_keeps_core_project_members
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '2'

    records = field.format.possible_values_records field, @issue

    assert_equal @issue.project.users.sorted.to_a, records.to_a
  end

  def test_missing_scope_falls_back_to_project_members
    field = IssueCustomField.create! name: 'Owner', field_format: 'user'

    records = field.format.possible_values_records field, @issue

    assert_equal @issue.project.users.sorted.to_a, records.to_a
  end

  def test_query_filter_values_for_scope_all_offers_all_visible_users
    field = IssueCustomField.create! name: 'Owner', field_format: 'user', user_scope: '1'
    query = IssueQuery.new

    ids = field.format.query_filter_values(field, query).pluck 1

    assert_includes ids, @locked_user.id.to_s
    assert_includes ids, 'me'
  end
end
