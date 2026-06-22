# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class EntityMethodTest < Additionals::TestCase
  include Redmine::I18n

  def setup
    prepare_tests
  end

  def test_allowed_entity_target_projects
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002)
    # When `redmine_templates` is installed, project 5 carries a
    # `TemplateProject` fixture and `Project.allowed_to_condition`
    # filters template projects out via NOT EXISTS template_projects.
    expected = template_project?(projects(:projects_005)) ? [1, 2] : [1, 2, 5]

    assert_sorted_equal expected, projects.ids
  end

  def test_allowed_entity_target_projects_with_project
    projects = Dashboard.allowed_entity_target_projects permission: :save_dashboards,
                                                        user: users(:users_002),
                                                        project: projects(:projects_003)
    expected = template_project?(projects(:projects_005)) ? [1, 2, 3] : [1, 2, 3, 5]

    assert_sorted_equal expected, projects.ids
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

  # Returns true if `redmine_templates` is installed and has tagged the
  # given project as a template (TemplateProject row exists). Used by
  # the `allowed_entity_target_projects` tests to adapt expectations
  # when `Project.allowed_to_condition` filters template projects out.
  def template_project?(project)
    defined?(TemplateProject) && TemplateProject.exists?(project_id: project.id)
  end

  # real_changes? must ignore an unsaved current_journal that only carries
  # transient, never-persisted detail objects (e.g. the child_id detail
  # Redmine builds on a parent issue when a child is attached). Counting them
  # as a real change logs empty saves and fires spurious automation jobs.
  # Regression for the .any? -> .count switch in JournalizedRealChanges.
  def test_real_changes_ignores_unsaved_journal_details
    dashboard = dashboards :private_welcome
    dashboard.reload
    journal = Journal.new user: users(:users_002)
    journal.details << JournalDetail.new(property: 'attr', prop_key: 'child_id', old_value: nil, value: '99')
    dashboard.instance_variable_set :@current_journal, journal

    assert_equal 0, journal.details.count
    assert journal.details.any?
    assert_not dashboard.real_changes?
  end

  def test_real_changes_detects_journal_notes
    dashboard = dashboards :private_welcome
    dashboard.reload
    dashboard.instance_variable_set :@current_journal, Journal.new(user: users(:users_002), notes: 'a note')

    assert dashboard.real_changes?
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

  def test_like_with_wildcard_finds_exact_match
    wikis = Wiki.like_with_wildcard columns: :start_page, value: 'Wiki', wildcard: :none

    assert_includes wikis.map(&:start_page), 'Wiki'
  end

  def test_like_with_wildcard_with_both_wildcard
    wikis = Wiki.like_with_wildcard columns: :start_page, value: 'ik', wildcard: :both

    assert_includes wikis.map(&:start_page), 'Wiki'
  end

  def test_like_with_wildcard_case_insensitive
    wikis = Wiki.like_with_wildcard columns: :start_page, value: 'wiki', wildcard: :none

    assert_includes wikis.map(&:start_page), 'Wiki'
  end

  def test_like_with_wildcard_with_right_wildcard
    wikis = Wiki.like_with_wildcard columns: :start_page, value: 'Wi', wildcard: :right

    assert_includes wikis.map(&:start_page), 'Wiki'
  end

  def test_like_with_wildcard_with_table_qualified_column
    wikis = Wiki.like_with_wildcard columns: 'wikis.start_page', value: 'Wiki', wildcard: :none

    assert_includes wikis.map(&:start_page), 'Wiki'
  end

  def test_like_with_wildcard_with_multiple_columns
    dashboards = Dashboard.like_with_wildcard columns: %w[dashboards.name dashboards.description],
                                              value: 'welcome',
                                              wildcard: :both

    assert_not_empty dashboards
  end
end
