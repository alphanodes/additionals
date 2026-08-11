# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WikiPageTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = users :users_002
    @wiki = wikis :wikis_001
    @recent_page = wiki_pages :wiki_pages_001
    @old_page = wiki_pages :wiki_pages_002
  end

  def test_recently_updated_skips_pages_outside_of_the_period
    change_page @recent_page, 1.day.ago
    change_page @old_page, 30.days.ago

    pages = WikiPage.recently_updated @wiki, days: 7

    assert_includes pages, @recent_page
    assert_not_includes pages, @old_page
  end

  def test_recently_updated_orders_by_last_change
    change_page @old_page, 3.days.ago
    change_page @recent_page, 1.day.ago

    pages = WikiPage.recently_updated @wiki, days: 7

    assert_equal [@recent_page, @old_page], pages.to_a.first(2)
  end

  def test_recently_updated_respects_limit
    change_page @recent_page, 1.day.ago
    change_page @old_page, 2.days.ago

    pages = WikiPage.recently_updated @wiki, days: 7, limit: 1

    assert_equal [@recent_page], pages.to_a
  end

  def test_recently_updated_without_limit
    change_page @recent_page, 1.day.ago
    change_page @old_page, 2.days.ago

    pages = WikiPage.recently_updated @wiki, days: 7

    assert_equal 2, pages.to_a.size
  end

  def test_recently_updated_skips_pages_of_other_wikis
    change_page @recent_page, 1.day.ago
    other_page = wiki_pages :wiki_pages_003
    change_page other_page, 1.day.ago

    pages = WikiPage.recently_updated @wiki, days: 7

    assert_not_equal @wiki.id, other_page.wiki_id
    assert_not_includes pages, other_page
  end

  private

  # Moves the last change of a page without touching the rest of the record, so
  # the fixture timestamps do not decide the outcome of the test.
  def change_page(page, time)
    page.content.update_columns updated_on: time
  end
end
