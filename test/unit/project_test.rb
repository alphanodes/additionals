# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class ProjectTest < Additionals::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :journals, :journal_details,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :custom_fields,
           :custom_fields_projects,
           :custom_fields_trackers,
           :custom_values,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :groups_users,
           :repositories,
           :workflows,
           :attachments,
           :dashboards, :dashboard_roles

  def setup
    prepare_tests
    User.current = nil
  end

  def test_assignable_users_amount
    with_settings issue_group_assignment: '1' do
      project = Project.find 5

      assert_equal project.assignable_users.count, project.assignable_principals.count
    end
    with_settings issue_group_assignment: '0' do
      project = Project.find 5

      assert_not_equal project.assignable_users.count, project.assignable_principals.count
    end
  end

  def test_visible_users
    project = projects :projects_005

    assert_equal 3, project.visible_users.count
  end

  def test_visible_principals
    project = projects :projects_005

    assert_equal 4, project.visible_principals.count
  end

  def test_destroy_project
    User.current = users :users_001

    @ecookbook = projects :projects_001
    # dashboards
    assert @ecookbook.dashboards.any?

    assert_difference 'Dashboard.count', -2 do
      @ecookbook.destroy
      # make sure that the project non longer exists
      assert_raise(ActiveRecord::RecordNotFound) { Project.find @ecookbook.id }
      # make sure related data was removed
      assert_nil Dashboard.where(project_id: @ecookbook.id).first
    end
  end

  def test_principals_by_role
    principals_by_role = Project.find(1).principals_by_role

    assert_kind_of Hash, principals_by_role
    role = Role.find 1

    assert_kind_of Array, principals_by_role[role]
    assert_includes principals_by_role[role], User.find(2)
  end

  def test_principals_by_role_with_hidden_role
    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role

    # User.current = User.find 2
    principals_by_role = Project.find(1).principals_by_role

    assert_equal 1, principals_by_role.count

    User.current = User.find 1
    principals_by_role = Project.find(1).principals_by_role

    assert_equal 2, principals_by_role.count
  end

  def test_active_new_ticket_message
    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      project = projects :projects_001

      assert_equal 'foo', project.active_new_ticket_message
    end
  end

  def test_active_new_ticket_message_and_disabled
    project = projects :projects_001
    project.update_attribute :enable_new_ticket_message, '0'

    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      assert_empty project.active_new_ticket_message
    end
  end

  def test_active_new_ticket_message_with_project_message
    project = projects :projects_001
    project.update_attribute :enable_new_ticket_message, '2'
    project.update_attribute :new_ticket_message, 'bar'

    with_plugin_settings 'additionals', new_ticket_message: 'foo' do
      assert_equal 'bar', project.active_new_ticket_message
    end
  end

  def test_consider_hidden_roles_without_hide_roles
    project = projects :projects_001

    assert_not project.consider_hidden_roles?
  end

  def test_consider_hidden_roles_with_hide_and_view_permission
    User.current = users :users_002
    project = projects :projects_001

    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role
    assert_not project.consider_hidden_roles?
  end

  def test_consider_hidden_roles_with_hide
    project = projects :projects_001

    role = Role.find 2
    role.hide = 1
    role.users_visibility = 'members_of_visible_projects'

    assert_save role
    assert project.consider_hidden_roles?
  end

  def test_usable_status_ids
    ids = Project.usable_status_ids

    assert_sorted_equal ids, [Project::STATUS_ACTIVE, Project::STATUS_CLOSED]
  end

  def test_sql_for_usable_status
    assert_equal "projects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status
    assert_equal "projects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status(:projects)
    assert_equal "subprojects.status IN(#{Project::STATUS_ACTIVE}, #{Project::STATUS_CLOSED})",
                 Project.sql_for_usable_status('subprojects')
  end

  def test_available_status_ids
    ids = Project.available_status_ids

    if Redmine::VERSION.to_s < '5.1'
      assert_equal 3, ids.count
    else
      assert_operator ids.count, :>, 3
    end
  end
end
