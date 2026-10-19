# frozen_string_literal: true

require 'ipaddr'
require 'net/http'

module DashboardBlocks
  class FeedBlock < Base
    # Reading a feed must not tie up the server
    TIMEOUT = 5
    MAX_FEED_SIZE = 1.megabyte
    MAX_REDIRECTS = 3

    block_id 'feed'
    label :label_additionals_feed
    max_occurs 20
    async required_settings: %i[url], cache_expires_in: 600, skip_user_id: true, partial: 'dashboards/blocks/feed'
    settings_partial 'dashboards/blocks/feed_settings'
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

    # The server reads the URL, so only for those who may set it on a dashboard
    def own_settings_allowed?
      user.allowed_to? :save_dashboards, project, global: true
    end

    private

    def read_feed
      feed = { items: [], valid: false }
      return feed if url.blank?

      RSS::Parser.parse(fetch(URI.parse(url))).items.first(max_entries).each do |item|
        feed[:items] << { title: item.title.try(:content).presence || item.title.to_s,
                          link: item.link.try(:href).presence || item.link.to_s }
      end
      feed.merge valid: true
    rescue StandardError => e
      Rails.logger.info "dashboard feed error for #{url}: #{e}"
      feed
    end

    # Only http and https, a few redirects, limited in time and size: the URL
    # may come from a program, not only from an editor of a dashboard. Hosts
    # of the intranet stay allowed, the server itself (loopback) not.
    def fetch(uri, redirects = MAX_REDIRECTS)
      raise ArgumentError, "unsupported scheme #{uri.scheme}" unless %w[http https].include? uri.scheme

      http = Net::HTTP.new uri.host, uri.port
      # Connects to the address checked, a second lookup could answer another
      http.ipaddr = remote_address uri.host
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http.start do
        http.request Net::HTTP::Get.new(uri) do |response|
          return fetch(URI.join(uri, response['location']), redirects - 1) if response.is_a?(Net::HTTPRedirection) && redirects.positive?

          response.value
          return read_limited response
        end
      end
    end

    def remote_address(host)
      address = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).first&.ip_address
      raise ArgumentError, "unknown host #{host}" if address.nil?
      raise ArgumentError, "loopback address #{address}" if IPAddr.new(address).loopback?

      address
    end

    def read_limited(response)
      body = +''
      response.read_body do |chunk|
        body << chunk
        raise ArgumentError, 'feed too large' if body.bytesize > MAX_FEED_SIZE
      end
      body
    end
  end
end
