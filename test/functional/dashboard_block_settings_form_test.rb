# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# The settings form of a block and its declared settings match, and the
# form built from them opens where the settings icon is
class DashboardBlockSettingsFormTest < Additionals::ControllerTest
  tests WelcomeController

  BLOCKS = %w[text text_async news documents my_spent_time feed activity issuequery issuequery__1].freeze

  def setup
    prepare_tests
    Setting.default_language = 'en'
    @request.session[:user_id] = 1
    User.current = users :users_001
  end

  def test_blocks_declare_the_settings_of_their_forms
    assert_dashboard_block_settings_declared BLOCKS,
                                             layout_settings: { 'issuequery__1' => { query_id: queries(:queries_004).id.to_s } }
  end

  # A block rendered with the page gets the form built from its settings
  def test_generated_settings_form_is_hidden_until_opened
    get :index, params: { dashboard_id: news_dashboard.id }

    assert_select 'div#news-settings.hidden input[name=?]', 'settings[news][max_entries]'
  end

  # It opens right below the settings icon, not below the content of the block
  def test_generated_settings_form_comes_before_the_content
    get :index, params: { dashboard_id: news_dashboard.id }

    assert_select '#block-news > .contextual + #news-settings'
  end

  # A new block shows its defaults, not empty fields
  def test_new_block_shows_the_default_max_entries
    get :index, params: { dashboard_id: news_dashboard.id }

    assert_select 'input[name=?][value=?]', 'settings[news][max_entries]', DashboardContent::DEFAULT_MAX_ENTRIES.to_s
  end

  def test_max_entries_are_required
    get :index, params: { dashboard_id: news_dashboard.id }

    assert_select 'label[for=settings_news_max_entries] span.required'
  end

  # Without the settings icon the form could not be opened
  def test_locked_dashboard_has_no_generated_settings_form
    get :index, params: { dashboard_id: news_dashboard(locked: true).id }

    assert_select 'div#news-settings', count: 0
  end

  # Like a block rendered with the page, e.g. a new block whose cancel would
  # remove it from the locked dashboard
  def test_locked_dashboard_has_no_settings_form_of_an_async_block
    get :index, params: { dashboard_id: feed_dashboard(locked: true).id }

    assert_select 'div#feed-settings', count: 0
  end

  # Opened on an existing block, the form names the block
  def test_settings_form_of_an_existing_block_is_named
    get :index, params: { dashboard_id: news_dashboard.id }

    assert_select 'div#news-settings > h3', text: 'Latest news settings'
  end

  def test_settings_form_of_an_existing_async_block_is_named
    get :index, params: { dashboard_id: feed_dashboard(url: 'https://example.org/feed.atom').id }

    assert_select 'div#feed-settings.hidden > h3', text: "#{I18n.t :label_additionals_feed} settings"
  end

  # A new block shows its form below its name, a second name would repeat it
  def test_settings_form_of_a_new_async_block_is_not_named
    get :index, params: { dashboard_id: feed_dashboard.id }

    assert_select 'div#feed-settings:not(.hidden):not(:has(> h3))'
  end

  # Like text_async, a new text block opens its form below its name
  def test_settings_form_of_a_block_without_its_required_settings_is_open_below_its_name
    get :index, params: { dashboard_id: text_dashboard.id }

    assert_select 'div#text-settings:not(.hidden) > h3', text: 'Text'
  end

  def test_settings_form_of_a_block_with_its_required_settings_is_hidden
    get :index, params: { dashboard_id: text_dashboard(text: 'Hello').id }

    assert_select 'div#text-settings.hidden > h3', text: 'Text settings'
  end

  # Cancel on a new block means not adding it
  def test_cancel_removes_a_new_block_without_asking
    dashboard = text_dashboard
    get :index, params: { dashboard_id: dashboard.id }

    assert_select '#text-settings a[href=?][data-remote-method=post]:not([data-remote-confirm])',
                  "/dashboards/#{dashboard.id}/remove_block?block=text", text: 'Cancel'
  end

  def test_cancel_removes_a_new_async_block
    dashboard = feed_dashboard
    get :index, params: { dashboard_id: dashboard.id }

    assert_select '#feed-settings a[href=?]', "/dashboards/#{dashboard.id}/remove_block?block=feed", text: 'Cancel'
  end

  # Its settings would be lost with it, e.g. of a block saved before its
  # text was required
  def test_cancel_keeps_a_block_that_lost_a_required_setting
    get :index, params: { dashboard_id: text_dashboard(settings: { title: 'Notes' }).id }

    assert_select '#text-settings a[href="#"]', text: 'Cancel'
  end

  # Closing the open form would leave the new block empty
  def test_new_block_has_no_settings_icon
    get :index, params: { dashboard_id: text_dashboard.id }

    assert_select '#block-text .contextual a.icon-settings', count: 0
  end

  def test_new_async_block_has_no_settings_icon
    get :index, params: { dashboard_id: feed_dashboard.id }

    assert_select '#block-feed .contextual a.icon-settings', count: 0
  end

  # Its open settings form tells what is missing
  def test_new_async_block_shows_no_no_data_hint
    get :index, params: { dashboard_id: feed_dashboard.id }

    assert_select '#block-feed p.nodata', count: 0
  end

  def test_block_with_its_settings_has_a_settings_icon
    get :index, params: { dashboard_id: text_dashboard(text: 'Hello').id }

    assert_select '#block-text .contextual a.icon-settings'
  end

  def test_query_of_a_query_list_is_labelled_query
    get :index, params: { dashboard_id: query_list_dashboard.id }

    assert_select 'label[for=settings_issuequery_query_id]', text: "#{I18n.t :label_query} *"
  end

  # The columns belong to a stored query
  def test_new_query_list_offers_no_columns
    get :index, params: { dashboard_id: query_list_dashboard.id }

    assert_select '[name^="settings[issuequery][columns]"]', count: 0
  end

  def test_query_list_with_its_query_offers_its_columns
    get :index, params: { dashboard_id: query_list_dashboard(query_id: queries(:queries_004).id.to_s).id }

    assert_select '.query-list-columns select[name=?]', 'settings[issuequery][columns][]'
  end

  # Otherwise an empty selection is not sent and the stored columns stay
  def test_query_list_sends_blank_columns_if_none_is_chosen
    get :index, params: { dashboard_id: query_list_dashboard(query_id: queries(:queries_004).id.to_s).id }

    assert_select 'input[type=hidden][name=?][value=""]', 'settings[issuequery][columns][]'
  end

  # Another query drops the own columns, the form resets them on a change
  def test_query_list_with_its_query_offers_another_query
    get :index, params: { dashboard_id: query_list_dashboard(query_id: queries(:queries_004).id.to_s).id }

    assert_select 'select[name=?]', 'settings[issuequery][query_id]'
  end

  private

  def query_list_dashboard(**settings)
    Dashboard.create! name: 'Issues', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current,
                      visibility: Dashboard::VISIBILITY_PUBLIC, layout: { 'top' => %w[issuequery] },
                      layout_settings: settings.any? ? { 'issuequery' => settings } : {}
  end

  def text_dashboard(text: nil, settings: nil)
    settings ||= text ? { text: } : nil
    Dashboard.create! name: 'Text', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current,
                      visibility: Dashboard::VISIBILITY_PUBLIC, layout: { 'top' => %w[text] },
                      layout_settings: settings ? { 'text' => settings } : {}
  end

  def news_dashboard(locked: false)
    Dashboard.create! name: 'News', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current,
                      visibility: Dashboard::VISIBILITY_PUBLIC, layout: { 'left' => %w[news] }, locked:
  end

  def feed_dashboard(url: nil, locked: false)
    Dashboard.create! name: 'Feed', dashboard_type: DashboardContentWelcome::TYPE_NAME, author: User.current,
                      visibility: Dashboard::VISIBILITY_PUBLIC, layout: { 'left' => %w[feed] },
                      layout_settings: url ? { 'feed' => { url: } } : {}, locked:
  end
end
