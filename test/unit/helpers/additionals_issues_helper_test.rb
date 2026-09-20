# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsIssuesHelperTest < Additionals::HelperTest
  include AdditionalsIssuesHelper
  include ERB::Util

  def test_link_to_issue_category_returns_link_when_enabled
    issue = issues :issues_001

    with_plugin_settings 'additionals', issue_link_category: 1 do
      html = link_to_issue_category issue

      assert_include 'issue-category-link', html
      assert_include "/projects/#{issue.project.identifier}/issues", html
      assert_include "category_id=#{issue.category_id}", html
      assert_include 'set_filter=1', html
      assert_include issue.category.name, html
    end
  end

  def test_link_to_issue_category_returns_plain_name_when_disabled
    issue = issues :issues_001

    with_plugin_settings 'additionals', issue_link_category: 0 do
      html = link_to_issue_category issue

      assert_not_include 'issue-category-link', html
      assert_not_include '<a', html
      assert_equal ERB::Util.h(issue.category.name), html
    end
  end

  def test_link_to_issue_category_returns_empty_string_without_category
    issue = issues :issues_002

    with_plugin_settings 'additionals', issue_link_category: 1 do
      assert_equal '', link_to_issue_category(issue)
    end
  end

  def test_link_to_issue_category_uses_passed_category
    issue = issues :issues_001
    category = issue_categories :issue_categories_002

    with_plugin_settings 'additionals', issue_link_category: 1 do
      html = link_to_issue_category issue, category: category

      assert_include "category_id=#{category.id}", html
    end
  end

  # link_to_issue_with_subject

  def test_link_to_issue_with_subject_puts_the_subject_inside_the_link
    issue = issues :issues_001

    html = link_to_issue_with_subject issue

    assert_include ">##{issue.id}: #{issue.subject}</a>", html
    assert_include "/issues/#{issue.id}", html
  end

  # The whole entry carries the issue's state, so core's a.issue.closed strikes
  # the line through instead of the number alone.
  def test_link_to_issue_with_subject_carries_the_state_classes
    issue = issues :issues_008

    assert_predicate issue, :closed?
    assert_include 'closed', link_to_issue_with_subject(issue)
    assert_not_include 'closed', link_to_issue_with_subject(issues(:issues_001))
  end

  def test_link_to_issue_with_subject_can_name_the_tracker
    issue = issues :issues_001

    assert_include ">#{issue.tracker} ##{issue.id}: ", link_to_issue_with_subject(issue, tracker: true)
  end

  def test_link_to_issue_with_subject_shortens_on_request_and_keeps_the_full_text_as_title
    issue = issues :issues_001
    issue.update_columns subject: 'a' * 80

    html = link_to_issue_with_subject issue.reload, truncate: 20

    assert_include '...', html
    assert_include %(title="#{'a' * 80}"), html
  end

  def test_link_to_issue_with_subject_escapes_the_subject
    issue = issues :issues_001
    issue.update_columns subject: '<script>alert(1)</script>'

    html = link_to_issue_with_subject issue.reload

    assert_not_include '<script>', html
    assert_include '&lt;script&gt;', html
  end
end
