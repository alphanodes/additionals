require File.expand_path('../../test_helper', __FILE__)

class DashboardTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses, :issue_categories, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :dashboards, :dashboard_roles

  def setup
    prepare_tests
    User.current = users :users_002
  end

  def test_create_welcome_dashboard
    dashboard = Dashboard.new name: 'my welcome dashboard',
                              dashboard_type: DashboardContentWelcome::TYPE_NAME,
                              author_id: 2

    assert dashboard.save
  end

  def test_create_project_dashboard
    dashboard = Dashboard.new name: 'my project dashboard',
                              dashboard_type: DashboardContentProject::TYPE_NAME,
                              project: Project.find(1),
                              author_id: 2

    assert dashboard.save
  end

  def test_system_default_welcome_should_exist
    assert_equal 1, Dashboard.welcome_only.where(system_default: true).count
  end

  def test_system_default_project_should_exist
    assert_equal 1, Dashboard.project_only.where(system_default: true).count
  end

  def test_change_system_default_welcome_requires_permission
    dashboard = Dashboard.new dashboard_type: DashboardContentWelcome::TYPE_NAME,
                              name: 'WelcomeTest',
                              system_default: true,
                              author: User.current,
                              visibility: 2
    assert dashboard.valid?

    User.current = users :users_004
    assert_raise(Exception) do
      dashboard.valid?
    end
  end

  def test_change_system_default_project_requires_permission
    dashboard = Dashboard.new dashboard_type: DashboardContentProject::TYPE_NAME,
                              name: 'ProjectTest',
                              system_default: true,
                              author: User.current,
                              visibility: 2
    assert dashboard.valid?

    User.current = users :users_004
    assert_raise(Exception) do
      dashboard.valid?
    end
  end

  def test_system_default_welcome_allowed_only_once
    assert Dashboard.create!(dashboard_type: DashboardContentWelcome::TYPE_NAME,
                             name: 'WelcomeTest',
                             system_default: true,
                             author: User.current,
                             visibility: 2)

    assert_equal 1, Dashboard.welcome_only.where(system_default: true).count
  end

  def test_system_default_project_allowed_only_once
    assert Dashboard.create!(dashboard_type: DashboardContentProject::TYPE_NAME,
                             name: 'ProjectTest',
                             system_default: true,
                             project_id: nil,
                             author: User.current,
                             visibility: 2)

    assert_equal 1, Dashboard.project_only.where(system_default: true).count
  end

  def test_system_default_welcome_requires_public_visibility
    dashboard = Dashboard.create!(dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                  name: 'WelcomeTest public',
                                  system_default: true,
                                  author: User.current,
                                  visibility: 2)

    assert dashboard.valid?

    dashboard.visibility = 0
    assert_not dashboard.valid?
  end

  def test_system_default_project_requires_public_visibility
    dashboard = Dashboard.new(dashboard_type: DashboardContentProject::TYPE_NAME,
                              name: 'ProjectTest public',
                              system_default: true,
                              project_id: nil,
                              author: User.current,
                              visibility: 2)
    assert dashboard.valid?

    dashboard.visibility = 0
    assert_not dashboard.valid?
  end

  def test_system_default_welcome_should_not_be_deletable
    assert_raise(Exception) do
      Dashboard.welcome_only
               .where(system_default: true)
               .destroy_all
    end
  end

  def test_system_default_project_should_not_be_deletable
    assert_raise(Exception) do
      Dashboard.project_only
               .where(system_default: true)
               .destroy_all
    end
  end

  def test_dashboard_with_unique_name_scope
    dashboard = Dashboard.new(dashboard_type: DashboardContentProject::TYPE_NAME,
                              author_id: 2,
                              visibility: 2)

    dashboard.name = 'Only for user 2'
    assert dashboard.valid?

    dashboard.project_id = 1
    dashboard.name = 'Private project for user 2'
    assert_not dashboard.valid?
    dashboard.name = 'Only for me - new'
    assert dashboard.valid?

    dashboard.name = 'Only for me - new'
    dashboard.project_id = 2
    assert dashboard.valid?
  end

  def test_dashboard_welcome_scope
    assert_equal 4, Dashboard.visible.welcome_only.count
  end

  def test_dashboard_project_scope
    assert_equal 2, Dashboard.visible.project_only.count
  end

  def test_destroy_dashboard_without_roles
    dashboard = dashboards :private_welcome2
    assert dashboard.roles.none?
    assert dashboard.destroyable_by? users(:users_002)
    assert_difference 'Dashboard.count', -1 do
      assert dashboard.destroy
    end
  end

  def test_create_dashboard_roles_relation
    dashboard = dashboards :welcome_for_roles
    assert_equal 2, dashboard.roles.count

    relation = DashboardRole.new(role_id: 3, dashboard_id: dashboard.id)
    assert relation.save

    dashboard.reload
    assert_equal 3, dashboard.roles.count
  end

  def test_create_dashboard_roles_relation_with_autosave
    dashboard = dashboards :welcome_for_roles
    assert_equal 2, dashboard.roles.count

    dashboard.roles << Role.generate!
    assert dashboard.save
    dashboard.reload
    assert_equal 3, dashboard.roles.count
  end

  def test_destroy_dashboard_with_roles
    User.current = users :users_001

    # change system default
    dashboard2 = dashboards :public_welcome
    dashboard2.system_default = true
    assert dashboard2.save

    dashboard = dashboards :welcome_for_roles
    dashboard.reload

    assert dashboard.roles.any?
    assert dashboard.destroyable_by? users(:users_001)
    assert_difference 'Dashboard.count', -1 do
      assert_difference 'DashboardRole.count', -2 do
        assert_no_difference 'Role.count' do
          assert dashboard.destroy
        end
      end
    end
  end
end
