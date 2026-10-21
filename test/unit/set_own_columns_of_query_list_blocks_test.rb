# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__
require File.expand_path '../../../db/migrate/011_set_own_columns_of_query_list_blocks', __FILE__

# Query list blocks with stored columns keep showing them
class SetOwnColumnsOfQueryListBlocksTest < Additionals::TestCase
  def setup
    prepare_tests
    @migration = SetOwnColumnsOfQueryListBlocks.new
    @migration.verbose = false
  end

  # A copy of the columns of its query: the block follows its query
  def test_up_drops_the_columns_of_the_query
    queries(:queries_004).update! column_names: %i[tracker subject]
    dashboard = dashboard_with 'issuequery' => { query_id: queries(:queries_004).id.to_s, columns: %w[tracker subject] }
    @migration.up

    assert_equal({ query_id: queries(:queries_004).id.to_s }, dashboard.reload.layout_settings('issuequery'))
  end

  # The migration runs without a user, who sees no column of a hidden field
  def test_up_drops_the_columns_of_the_query_also_with_a_hidden_custom_field
    User.current = nil
    field = IssueCustomField.create! name: 'Hidden', field_format: 'string', is_for_all: true, visible: false,
                                     role_ids: [roles(:roles_001).id]
    columns = ['tracker', "cf_#{field.id}"]
    queries(:queries_004).update! column_names: columns
    dashboard = dashboard_with 'issuequery' => { query_id: queries(:queries_004).id.to_s, columns: }
    @migration.up

    assert_equal({ query_id: queries(:queries_004).id.to_s }, dashboard.reload.layout_settings('issuequery'))
  end

  # A query without columns of its own shows its defaults
  def test_up_drops_the_default_columns_of_the_query
    query = queries :queries_004
    dashboard = dashboard_with 'issuequery' => { query_id: query.id.to_s, columns: query.default_columns_names.map(&:to_s) }
    @migration.up

    assert_equal({ query_id: query.id.to_s }, dashboard.reload.layout_settings('issuequery'))
  end

  # Run again, e.g. after an earlier version marked them
  def test_up_lets_own_columns_equal_to_those_of_the_query_follow_it
    queries(:queries_004).update! column_names: %i[tracker subject]
    dashboard = dashboard_with 'issuequery' => { query_id: queries(:queries_004).id.to_s, own_columns: '1',
                                                 columns: %w[tracker subject] }
    @migration.up

    assert_equal({ query_id: queries(:queries_004).id.to_s }, dashboard.reload.layout_settings('issuequery'))
  end

  def test_up_marks_other_columns_as_own
    queries(:queries_004).update! column_names: %i[tracker subject]
    dashboard = dashboard_with 'issuequery' => { query_id: queries(:queries_004).id.to_s, columns: %w[subject] }
    @migration.up

    assert_equal '1', dashboard.reload.layout_settings('issuequery')[:own_columns]
  end

  # Its columns stay as they were shown
  def test_up_marks_the_columns_of_a_deleted_query_as_own
    dashboard = dashboard_with 'issuequery' => { query_id: '999999', columns: %w[subject] }
    @migration.up

    assert_equal '1', dashboard.reload.layout_settings('issuequery')[:own_columns]
  end

  # It follows the columns of its query already
  def test_up_leaves_a_block_without_columns
    dashboard = dashboard_with 'issuequery' => { query_id: '1' }
    @migration.up

    assert_equal({ query_id: '1' }, dashboard.reload.layout_settings('issuequery'))
  end

  private

  def dashboard_with(layout_settings)
    dashboard = Dashboard.create! name: 'Query lists', dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  author: users(:users_001), visibility: Dashboard::VISIBILITY_PUBLIC
    dashboard.options = { layout: { 'top' => layout_settings.keys }, layout_settings: }
    dashboard.save!
    dashboard
  end
end
