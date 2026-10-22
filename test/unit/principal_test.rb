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

  def test_visible_for_members_of_visible_projects_hides_members_of_hidden_roles
    viewer = prepare_members_of_visible_projects_viewer

    assert_equal [2, 3, 7], Principal.visible(viewer).order(:id).ids
  end

  def test_visible_for_members_of_visible_projects_with_show_hidden_roles_in_memberbox
    viewer = prepare_members_of_visible_projects_viewer show_hidden_roles: true

    assert_equal [2, 3, 4, 7], Principal.visible(viewer).order(:id).ids
  end

  def test_visible_for_user_with_a_role_with_all_users_visibility
    viewer = prepare_members_of_visible_projects_viewer
    Member.create! project: projects(:projects_002), principal: viewer, roles: [roles(:roles_002)]

    assert_equal Principal.active.order(:id).ids, Principal.visible(viewer).order(:id).ids

    # A role of an archived project does not count
    assert projects(:projects_002).archive

    assert_equal [2, 3, 7], Principal.visible(viewer.reload).order(:id).ids
  end

  def test_assignable_for_issues_for_members_of_visible_projects
    User.current = prepare_members_of_visible_projects_viewer
    project = projects :projects_001

    assert_equal [2, 3, 7], Principal.assignable_for_issues(project).order(:id).ids
    assert_equal [2, 3, 7], Principal.assignable_for_issues.order(:id).ids
  end

  def test_assignable_for_issues_for_members_of_visible_projects_with_show_hidden_roles_in_memberbox
    User.current = prepare_members_of_visible_projects_viewer show_hidden_roles: true
    project = projects :projects_001

    assert_equal [2, 3, 4, 7], Principal.assignable_for_issues(project).order(:id).ids
    assert_equal [2, 3, 4, 7], Principal.assignable_for_issues.order(:id).ids
  end

  def test_assignable_for_issues_is_sortable
    project = projects :projects_005
    ids = Principal.assignable_for_issues(project).sorted.pluck(:id)
    expected = Principal.where(id: ids).sorted.pluck(:id)

    assert_equal expected, ids,
                 'assignable_for_issues does not respect Principal.sorted order when chained'
  end

  private

  # Viewer (users_007) sees the members of the public projects 1, 3, 4 and 6: users_002 and
  # users_003 (users_005 is locked) plus users_004 with a hidden role. The members of the
  # private projects 2 and 5 (users_001, users_008, the groups) stay invisible.
  def prepare_members_of_visible_projects_viewer(show_hidden_roles: false)
    permissions = %i[view_project view_issues]
    permissions << :show_hidden_roles_in_memberbox if show_hidden_roles
    role = Role.generate! users_visibility: 'members_of_visible_projects', assignable: true, permissions: permissions
    hidden_role = Role.generate! users_visibility: 'members_of_visible_projects', assignable: true, hide: true

    project = projects :projects_001
    viewer = users :users_007
    Member.create! project: project, principal: viewer, roles: [role]
    Member.create! project: project, principal: users(:users_004), roles: [hidden_role]

    viewer
  end
end
