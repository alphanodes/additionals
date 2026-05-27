# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class PrincipalTest < Additionals::TestCase
  def setup
    prepare_tests
  end

  # PostgreSQL strict mode rejects `SELECT DISTINCT … ORDER BY users.type`
  # when `users.type` is not in the SELECT list (raises
  # PG::InvalidColumnReference). MySQL silently tolerates it. Materializing
  # the relation into an Array forces query execution and surfaces the bug
  # on PG without needing adapter-specific test branches.
  def test_assignable_for_issues_can_be_materialized_with_sorted_chain
    project = projects :projects_005

    result = nil
    assert_nothing_raised do
      result = Principal.assignable_for_issues(project).sorted.to_a
    end
    assert_kind_of Array, result
  end

  def test_assignable_for_issues_can_be_materialized_without_project
    result = nil
    assert_nothing_raised do
      result = Principal.assignable_for_issues.sorted.to_a
    end
    assert_kind_of Array, result
  end

  def test_assignable_for_issues_returns_unique_principals
    project = projects :projects_005
    ids = Principal.assignable_for_issues(project).pluck(:id)

    assert_equal ids.size, ids.uniq.size,
                 'assignable_for_issues returned duplicate principals'
  end

  def test_assignable_for_issues_filters_by_project
    project = projects :projects_005
    ids = Principal.assignable_for_issues(project).pluck(:id)

    member_ids = Member.where(project_id: project.id).pluck(:user_id).uniq

    assert_empty (ids - member_ids),
                 "assignable_for_issues returned principals not member of project: #{(ids - member_ids).inspect}"
  end

  def test_assignable_for_issues_excludes_groups_when_setting_disabled
    project = projects :projects_005

    with_settings issue_group_assignment: '0' do
      ids = Principal.assignable_for_issues(project).pluck(:id)
      types = Principal.where(id: ids).pluck(:type)

      assert_not_includes types, 'Group',
                          'assignable_for_issues should exclude Groups when issue_group_assignment is disabled'
    end
  end

  def test_assignable_for_issues_includes_groups_when_setting_enabled
    project = projects :projects_005

    with_count = with_settings issue_group_assignment: '1' do
      Principal.assignable_for_issues(project).count
    end
    without_count = with_settings issue_group_assignment: '0' do
      Principal.assignable_for_issues(project).count
    end

    assert_operator with_count, :>=, without_count,
                    'assignable_for_issues with groups must include at least as many principals as without groups'
  end

  def test_assignable_for_issues_is_sortable
    project = projects :projects_005
    ids = Principal.assignable_for_issues(project).sorted.pluck(:id)
    expected = Principal.where(id: ids).sorted.pluck(:id)

    assert_equal expected, ids,
                 'assignable_for_issues does not respect Principal.sorted order when chained'
  end
end
