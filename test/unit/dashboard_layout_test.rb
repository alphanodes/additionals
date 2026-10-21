# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardLayoutTest < Additionals::TestCase
  FEED_URL = 'https://example.org/feed'

  def setup
    prepare_tests
    User.current = users :users_002
    @dashboard = Dashboard.new name: 'Layout', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current
  end

  def test_assign_layout
    @dashboard.assign_layout 'top' => [{ block: 'feed', settings: { url: FEED_URL } }], 'left' => %w[news]

    assert_equal({ 'top' => %w[feed], 'left' => %w[news], 'right' => [], 'bottom' => [] }, @dashboard.layout)
  end

  def test_assign_layout_stores_the_settings
    @dashboard.assign_layout 'top' => [{ block: 'feed', settings: { url: FEED_URL } }]

    assert_equal({ url: FEED_URL }, @dashboard.layout_settings('feed'))
  end

  def test_assign_layout_succeeds
    assert_predicate @dashboard.assign_layout('top' => %w[news]), :success?
  end

  def test_assign_layout_accepts_string_keys
    @dashboard.assign_layout top: [{ 'block' => 'feed', 'settings' => { 'url' => FEED_URL } }]

    assert_equal({ url: FEED_URL }, @dashboard.layout_settings('feed'))
  end

  def test_assign_layout_keeps_the_settings_of_a_block_without_settings
    @dashboard.update_block_settings 'feed__2', url: FEED_URL
    @dashboard.assign_layout 'left' => %w[feed__2]

    assert_equal({ url: FEED_URL }, @dashboard.layout_settings('feed__2'))
  end

  def test_assign_layout_replaces_the_settings_of_a_block
    @dashboard.update_block_settings 'feed', url: FEED_URL, max_entries: '5'
    @dashboard.assign_layout 'left' => [{ block: 'feed', settings: { url: FEED_URL } }]

    assert_equal({ url: FEED_URL }, @dashboard.layout_settings('feed'))
  end

  def test_merge_layout_completes_the_stored_settings
    @dashboard.update_block_settings 'feed', url: FEED_URL
    @dashboard.merge_layout 'left' => [{ block: 'feed', settings: { max_entries: '5' } }]

    assert_equal({ url: FEED_URL, max_entries: '5' }, @dashboard.layout_settings('feed'))
  end

  def test_assign_layout_drops_the_settings_of_removed_blocks
    @dashboard.update_block_settings 'feed', url: FEED_URL
    @dashboard.assign_layout 'left' => %w[news]

    assert_empty @dashboard.layout_settings.keys - ['news']
  end

  def test_assign_layout_reports_unknown_settings
    result = @dashboard.assign_layout 'top' => [{ block: 'feed', settings: { url: FEED_URL, chart: 'pie' } }]

    assert_equal({ 'feed' => [:chart] }, result.ignored)
  end

  def test_unknown_block_is_rejected
    result = @dashboard.assign_layout 'top' => %w[news unknown]

    assert_equal ['unknown'], error_keys(result)
  end

  def test_invalid_block_id_is_rejected
    result = @dashboard.assign_layout 'top' => %w[feed__x]

    assert_equal ['feed__x'], error_keys(result)
  end

  def test_unknown_group_is_rejected
    result = @dashboard.assign_layout 'middle' => %w[news]

    assert_equal [:base], error_keys(result)
  end

  def test_layout_from_parameters
    params = ActionController::Parameters.new 'top' => [{ 'block' => 'feed', 'settings' => { 'url' => FEED_URL } }]
    @dashboard.assign_layout params

    assert_equal({ url: FEED_URL }, @dashboard.layout_settings('feed'))
  end

  def test_layout_that_is_no_hash_is_rejected
    assert_equal [:base], error_keys(@dashboard.assign_layout(%w[news]))
  end

  def test_group_that_is_no_list_is_rejected
    assert_equal [:base], error_keys(@dashboard.assign_layout('top' => { block: 'news' }))
  end

  def test_settings_that_are_no_hash_are_rejected
    assert_equal ['feed'], error_keys(@dashboard.assign_layout('top' => [{ block: 'feed', settings: 'x' }]))
  end

  def test_duplicate_block_is_rejected
    result = @dashboard.assign_layout 'top' => %w[news], 'left' => %w[news]

    assert_equal ['news'], error_keys(result)
  end

  def test_block_beyond_max_occurs_is_rejected
    result = @dashboard.assign_layout 'top' => %w[news news__2]

    assert_equal ['news__2'], error_keys(result)
  end

  def test_block_with_several_occurs_is_accepted
    assert_predicate @dashboard.assign_layout('top' => %w[feed feed__2]), :success?
  end

  def test_block_without_permission_is_rejected
    Role.find_each { |role| role.remove_permission! :view_news }
    result = @dashboard.assign_layout 'top' => %w[news]

    assert_equal ['news'], error_keys(result)
  end

  # A program only sees the blocks it can use: a stored block it cannot use
  # here must not get lost when it writes the layout back
  def test_assign_layout_keeps_a_stored_block_the_user_cannot_use
    store_news_without_permission 'left' => %w[news feed]
    @dashboard.assign_layout 'left' => %w[feed text]

    assert_equal %w[news feed text], @dashboard.layout['left']
  end

  def test_assign_layout_keeps_the_settings_of_a_stored_block_the_user_cannot_use
    store_news_without_permission 'left' => %w[news]
    @dashboard.assign_layout 'left' => %w[feed]

    assert_equal({ max_entries: '3' }, @dashboard.layout_settings('news'))
  end

  def test_assign_layout_accepts_a_stored_block_the_user_cannot_use
    store_news_without_permission 'left' => %w[news]

    assert_predicate @dashboard.assign_layout('left' => %w[news feed]), :success?
  end

  def test_assign_layout_moves_a_stored_block_the_user_cannot_use
    store_news_without_permission 'left' => %w[news]
    @dashboard.assign_layout 'right' => %w[news]

    assert_equal [[], %w[news]], @dashboard.layout.values_at('left', 'right')
  end

  def test_assign_layout_rejects_settings_of_a_block_the_user_cannot_use
    store_news_without_permission 'left' => %w[news]
    result = @dashboard.assign_layout 'left' => [{ block: 'news', settings: { max_entries: '5' } }]

    assert_equal ['news'], error_keys(result)
  end

  def test_layout_export_marks_a_block_the_editor_cannot_use
    store_news_without_permission 'left' => %w[news]
    User.current = users :users_002

    assert_equal [{ block: 'news', available: false }], @dashboard.layout_export['left']
  end

  def test_layout_export_leaves_out_a_block_a_reader_cannot_use
    store_news_without_permission 'left' => %w[news]
    User.current = users :users_003

    assert_empty @dashboard.layout_export['left']
  end

  def test_invalid_setting_is_rejected_per_block_and_setting
    result = @dashboard.assign_layout 'top' => [{ block: 'feed', settings: { url: FEED_URL, max_entries: '500' } }]

    assert_equal({ 'feed' => [:max_entries] }, result.errors.transform_values { |errors| errors.map(&:first) })
  end

  def test_invalid_setting_leaves_the_dashboard_unchanged
    @dashboard.assign_layout 'top' => %w[news]
    @dashboard.assign_layout 'left' => ['documents', { block: 'feed', settings: { max_entries: '500' } }]

    assert_equal({ 'top' => %w[news], 'left' => [], 'right' => [], 'bottom' => [] }, @dashboard.layout)
  end

  def test_locked_dashboard_is_rejected
    User.current = users :users_001
    dashboard = dashboards :system_default_welcome
    result = dashboard.assign_layout 'top' => %w[news]

    assert_equal [:base], error_keys(result)
  end

  def test_locked_dashboard_stays_unchanged
    User.current = users :users_001
    dashboard = dashboards :system_default_welcome
    layout = dashboard.layout.deep_dup
    dashboard.assign_layout 'top' => %w[news]

    assert_equal layout, dashboard.layout
  end

  def test_dashboard_of_another_user_is_rejected
    dashboard = dashboards :private_welcome

    assert_equal [:base], error_keys(dashboard.assign_layout('top' => %w[news]))
  end

  def test_assigned_layout_can_be_saved
    @dashboard.assign_layout 'top' => [{ block: 'feed', settings: { url: FEED_URL } }]

    assert_save @dashboard
  end

  private

  def error_keys(result)
    result.errors.map(&:first)
  end

  def store_news_without_permission(layout)
    @dashboard.layout = layout
    @dashboard.layout_settings = { 'news' => { max_entries: '3' } }
    Role.find_each { |role| role.remove_permission! :view_news }
  end
end
