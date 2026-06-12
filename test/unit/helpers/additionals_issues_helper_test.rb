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
end
