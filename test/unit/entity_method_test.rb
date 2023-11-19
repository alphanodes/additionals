# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class EntityMethodTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issue_categories, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_allowed_entity_target_projects
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002)

    assert_sorted_equal [1, 2, 5], projects.ids
  end

  def test_allowed_entity_target_projects_with_project
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002),
                                                        project: projects(:projects_003)

    assert_sorted_equal [1, 2, 3, 5], projects.ids
  end

  def test_allowed_entity_target_projects_with_exclude_project
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002),
                                                        exclude: projects(:projects_005)

    assert_sorted_equal [1, 2], projects.ids
  end

  def test_allowed_entity_target_projects_with_project_and_exclude
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002),
                                                        project: projects(:projects_003),
                                                        exclude: projects(:projects_005)

    assert_sorted_equal [1, 2, 3], projects.ids
  end

  def test_like_pattern
    assert_equal 'ss', Wiki.like_pattern(' ss ')
    assert_equal 'ss%', Wiki.like_pattern('ss', :right)
    assert_equal '%ss', Wiki.like_pattern('ss', :left)
    assert_equal '%ss%', Wiki.like_pattern('ss', :both)
    assert_equal 'ss', Wiki.like_pattern('ss', :none)
  end

  def test_like_with_wildcard
    assert_empty Wiki.like_with_wildcard(columns: :start_page, value: 'nothing')
  end

  def test_like_with_wildcard_with_empty_value
    assert_empty Wiki.like_with_wildcard(columns: :start_page, value: '')
  end
end
