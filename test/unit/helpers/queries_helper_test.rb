# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class QueriesHelperTest < Additionals::HelperTest
  include QueriesHelper
  include AdditionalsIssuesHelper
  include ERB::Util

  def setup
    super
    User.current = users :users_002
  end

  def test_column_value_renders_issue_category_as_link
    issue = issues :issues_001

    with_plugin_settings 'additionals', issue_link_category: 1 do
      result = column_value QueryColumn.new(:category), issue, issue.category

      assert_include 'issue-category-link', result
      assert_include "category_id=#{issue.category_id}", result
      assert_include issue.category.name, result
    end
  end

  def test_column_value_renders_issue_category_as_plain_name_when_link_disabled
    issue = issues :issues_001

    with_plugin_settings 'additionals', issue_link_category: 0 do
      result = column_value QueryColumn.new(:category), issue, issue.category

      assert_equal h(issue.category.name), result
    end
  end

  # The category branch must only trigger for issues; everything else has to
  # reach Redmine core through super.
  def test_column_value_of_category_column_on_non_issue_is_rendered_by_core
    category = issue_categories :issue_categories_001
    project = projects :projects_001

    with_plugin_settings 'additionals', issue_link_category: 1 do
      result = column_value QueryColumn.new(:category), project, category

      assert_equal h(category.name), result
    end
  end

  def test_column_value_of_core_column_is_rendered_by_core
    issue = issues :issues_001

    result = column_value QueryColumn.new(:subject), issue, issue.subject

    assert_equal link_to(issue.subject, issue_path(issue)), result
  end
end
