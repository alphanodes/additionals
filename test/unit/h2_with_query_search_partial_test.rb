# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Plugins render the shared page title with live search above their query lists
class H2WithQuerySearchPartialTest < Additionals::HelperTest
  def setup
    super
    prepare_tests
    User.current = users :users_001
    @redmine_view = build_redmine_view
    @redmine_view.assign query: IssueQuery.new
  end

  # The browser history of the field would cover the live filtered list
  def test_search_field_offers_no_browser_history
    html = @redmine_view.render partial: 'additionals/h2_with_query_search',
                                locals: { title: :label_issue_plural, q: nil }
    field = Nokogiri::HTML.fragment(html).at_css 'h2.live-search input#search'

    assert_equal 'off', field['autocomplete']
  end
end
