# frozen_string_literal: true

module DashboardBlocks
  class FeedBlock < Base
    block_id 'feed'
    label :label_additionals_feed
    max_occurs 20
    async required_settings: %i[url], cache_expires_in: 600, skip_user_id: true, partial: 'dashboards/blocks/feed'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :url, type: :string, label: :field_url, required: true
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING
  end
end
