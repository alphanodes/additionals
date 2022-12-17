# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class WikiPageTest < Additionals::TestCase
  fixtures :projects, :users, :roles,
           :members, :member_roles,
           :trackers,
           :groups_users,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issues,
           :enumerations, :watchers,
           :custom_fields, :custom_values, :custom_fields_trackers,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    prepare_tests
    User.current = nil
  end

  def test_my_watched_pages
    page = wiki_pages :wiki_pages_001
    page.add_watcher users(:users_002)

    assert_equal 1, WikiPage.my_watched_pages(users(:users_002)).count
    assert_equal 1, WikiPage.my_watched_pages(users(:users_001)).count # one existing entry
    assert_equal 0, WikiPage.my_watched_pages.count
  end

  def test_my_watched_should_latest_first
    page1 = wiki_pages :wiki_pages_001
    page1.add_watcher users(:users_002)

    page2 = wiki_pages :wiki_pages_002
    page2.add_watcher users(:users_002)

    watched_pages = WikiPage.my_watched_pages users(:users_002)

    assert_equal 2, watched_pages.count
    assert_equal page2.id, watched_pages.first.id
  end
end
