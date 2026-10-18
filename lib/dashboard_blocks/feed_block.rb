# frozen_string_literal: true

require 'open-uri'

module DashboardBlocks
  class FeedBlock < Base
    block_id 'feed'
    label :label_additionals_feed
    max_occurs 20
    async required_settings: %i[url], cache_expires_in: 600, skip_user_id: true, partial: 'dashboards/blocks/feed'
    setting :title, **DashboardContent::TITLE_SETTING
    setting :url, type: :string, label: :field_url, required: true
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING

    # The entries of the feed, valid is false if it cannot be read
    def data
      @data ||= read_feed
    end

    def export_data
      data
    end

    private

    def read_feed
      feed = { items: [], valid: false }
      return feed if url.blank?

      URI.parse(url).open do |rss_feed|
        RSS::Parser.parse(rss_feed).items.first(max_entries).each do |item|
          feed[:items] << { title: item.title.try(:content).presence || item.title.to_s,
                            link: item.link.try(:href).presence || item.link.to_s }
        end
      end
      feed.merge valid: true
    rescue StandardError => e
      Rails.logger.info "dashboard feed error for #{url}: #{e}"
      feed
    end
  end
end
