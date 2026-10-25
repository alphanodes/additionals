# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Reading the feed of a feed block: only http and https, a limited size and
# time, so a URL of a request cannot make the server read anything else
class FeedBlockTest < Additionals::TestCase
  # A documentation address (TEST-NET-3): no name to resolve
  FEED_URL = 'https://203.0.113.10/feed.xml'
  RSS = <<~XML
    <?xml version="1.0"?>
    <rss version="2.0"><channel><title>News</title><link>https://example.org</link><description>News</description>
    <item><title>First entry</title><link>https://example.org/1</link></item>
    </channel></rss>
  XML

  def setup
    prepare_tests
    User.current = users :users_001
  end

  def test_feed_lists_its_entries
    stub_request(:get, FEED_URL).to_return body: RSS

    assert_equal ['First entry'], feed(FEED_URL).data[:items].pluck(:title)
  end

  def test_feed_of_another_scheme_is_not_read
    assert_not feed('ftp://203.0.113.10/feed.xml').data[:valid]
  end

  def test_feed_of_the_server_itself_is_not_read
    stub_request(:get, 'http://127.0.0.1/feed.xml').to_return body: RSS

    assert_not feed('http://127.0.0.1/feed.xml').data[:valid]
  end

  def test_feed_of_the_server_itself_by_ipv6_is_not_read
    stub_request(:get, 'http://[::1]/feed.xml').to_return body: RSS

    assert_not feed('http://[::1]/feed.xml').data[:valid]
  end

  # The unspecified address reaches the local host too, link-local the metadata of cloud hosts
  def test_feed_of_other_local_addresses_is_not_read
    urls = %w[http://0.0.0.0/feed.xml http://[::]/feed.xml http://169.254.169.254/feed.xml http://[::ffff:127.0.0.1]/feed.xml]
    urls.each { |url| stub_request(:get, url).to_return body: RSS }

    assert_equal([false] * urls.size, urls.map { |url| feed(url).data[:valid] })
  end

  def test_feed_of_the_intranet_is_read
    stub_request(:get, 'http://10.0.0.5/feed.xml').to_return body: RSS

    assert_predicate feed('http://10.0.0.5/feed.xml').data[:items], :any?
  end

  def test_feed_beyond_the_size_limit_is_not_valid
    stub_request(:get, FEED_URL).to_return body: RSS + (' ' * DashboardBlocks::FeedBlock::MAX_FEED_SIZE)

    assert_not feed(FEED_URL).data[:valid]
  end

  def test_feed_follows_a_redirect
    stub_request(:get, 'https://203.0.113.10/old.xml').to_return status: 302, headers: { 'Location' => FEED_URL }
    stub_request(:get, FEED_URL).to_return body: RSS

    assert_predicate feed('https://203.0.113.10/old.xml').data[:items], :any?
  end

  def test_feed_does_not_follow_a_redirect_to_another_scheme
    stub_request(:get, FEED_URL).to_return status: 302, headers: { 'Location' => 'ftp://203.0.113.10/feed.xml' }

    assert_not feed(FEED_URL).data[:valid]
  end

  def test_feed_does_not_follow_redirects_endlessly
    stub_request(:get, FEED_URL).to_return status: 302, headers: { 'Location' => FEED_URL }

    assert_not feed(FEED_URL).data[:valid]
  end

  private

  def feed(url)
    DashboardBlocks::FeedBlock.new DashboardContentWelcome.new, settings: { url: }
  end
end
