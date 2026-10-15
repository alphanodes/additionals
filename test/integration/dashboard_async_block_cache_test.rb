# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class DashboardAsyncBlockCacheTest < Additionals::IntegrationTest
  def setup
    prepare_tests
    @dashboard = dashboards :system_default_welcome
    @issue = issues :issues_003
    log_user 'admin', 'admin'
  end

  def test_refresh_replaces_cached_query_list_block
    with_fragment_cache do
      block_url = cache_block 'issuequery'
      @issue.update_column :subject, 'Subject after refresh'
      get '/', params: { dashboard_id: @dashboard.id, refresh: 1 }
      get block_url

      assert_includes response.body, 'Subject after refresh'
    end
  end

  def test_query_list_block_without_refresh_is_delivered_from_cache
    with_fragment_cache do
      block_url = cache_block 'issuequery'
      @issue.update_column :subject, 'Subject without refresh'
      get '/', params: { dashboard_id: @dashboard.id }
      get block_url

      assert_not_includes response.body, 'Subject without refresh'
    end
  end

  def test_refresh_keeps_cached_blocks_without_query
    with_fragment_cache do
      cache_block 'text_async'
      get '/', params: { dashboard_id: @dashboard.id, refresh: 1 }

      assert_select '#block-text_async', text: /Use it for better performance/
    end
  end

  private

  # Loads the dashboard and the block content once, so the block is in the cache.
  # Returns the URL the dashboard loads the block content from.
  def cache_block(block)
    get '/', params: { dashboard_id: @dashboard.id }
    block_url = css_select("#block-#{block} [data-render-async-url-value]").first['data-render-async-url-value']
    get block_url, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

    assert_response :success
    block_url
  end
end
