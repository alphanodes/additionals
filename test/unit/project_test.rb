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
           :attachments

  def setup
    User.current = nil
  end

  def test_assignable_users_amount
    with_settings issue_group_assignment: '1' do
      project = Project.find 5
      assert_equal project.assignable_users.count, project.assignable_users_and_groups.count
    end
    with_settings issue_group_assignment: '0' do
      project = Project.find 5
      assert_not_equal project.assignable_users.count, project.assignable_users_and_groups.count
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

    @ecookbook.destroy
    # make sure that the project non longer exists
    assert_raise(ActiveRecord::RecordNotFound) { Project.find @ecookbook.id }
    # make sure related data was removed
    assert_nil Dashboard.where(project_id: @ecookbook.id).first
  end

  def test_users_by_role
    users_by_role = if Redmine::VERSION.to_s >= '4.2'
                      Project.find(1).principals_by_role
                    else
                      Project.find(1).users_by_role
                    end

    assert_kind_of Hash, users_by_role
    role = Role.find 1
    assert_kind_of Array, users_by_role[role]
    assert users_by_role[role].include?(User.find(2))
  end

  def test_users_by_role_with_hidden_role
    Role.update_all users_visibility: 'members_of_visible_projects'

    role = Role.find 2
    role.hide = 1
    role.save!

    assert_equal 0, Role.where.not(users_visibility: 'members_of_visible_projects').count
    assert role.hide

    # User.current = User.find 2
    users_by_role = if Redmine::VERSION.to_s >= '4.2'
                      Project.find(1).principals_by_role
                    else
                      Project.find(1).users_by_role
                    end
    assert_equal 1, users_by_role.count

    User.current = User.find 1
    users_by_role = if Redmine::VERSION.to_s >= '4.2'
                      Project.find(1).principals_by_role
                    else
                      Project.find(1).users_by_role
                    end
    assert_equal 2, users_by_role.count
  end
end
