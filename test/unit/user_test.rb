# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class UserTest < Additionals::TestCase
  fixtures :users, :groups_users, :email_addresses,
           :members, :projects, :roles, :member_roles, :auth_sources,
           :trackers, :issue_statuses,
           :projects_trackers,
           :watchers,
           :issue_categories, :enumerations, :issues,
           :journals, :journal_details,
           :enabled_modules,
           :tokens, :user_preferences,
           :dashboards, :dashboard_roles

  def setup
    prepare_tests
    User.current = users :users_002
  end

  def test_with_permission
    admin_user = User.generate! admin: true

    users = User.visible.active.with_permission :save_dashboards

    assert_equal 5, users.count
    assert users.exists?(id: admin_user)
  end

  def test_with_permission_on_project
    assert_equal 3, User.visible.active.with_permission(:save_dashboards, projects(:projects_001)).count
  end

  def test_admin_should_can_be_admin
    assert User.where(admin: true).first.can_be_admin?
  end

  def test_non_admin_should_can_not_be_admin
    assert_not User.where(admin: false).first.can_be_admin?
  end

  def test_sudoer_should_can_be_admin
    skip 'Skip redmine_sudo test, because redmine_contacts is not installed' unless AdditionalsPlugin.active_sudo?

    user = users :users_001
    user.sudoer = true

    assert_save user
    user.reload

    assert user.sudoer
    assert user.admin
    assert User.where(sudoer: true).first.can_be_admin?

    user.admin = false

    assert_save user
    user.reload

    assert user.sudoer
    assert_not user.admin
    assert User.where(sudoer: true).first.can_be_admin?
  end

  def test_non_sudoer_without_admin_can_not_be_admin
    skip 'Skip redmine_sudo test, because redmine_contacts is not installed' unless AdditionalsPlugin.active_sudo?

    assert_not User.where(sudoer: false, admin: false).first.can_be_admin?
  end

  def test_allowed_project_ids_for
    user = users :users_002

    assert_sorted_equal Project.where(Project.allowed_to_condition(user, :view_issues)).ids,
                        user.allowed_project_ids_for(:view_issues)

    # test cache
    assert_sorted_equal Project.where(Project.allowed_to_condition(user, :view_issues)).ids,
                        user.allowed_project_ids_for(:view_issues)
  end

  def test_allowed_project_ids_for_with_options
    user = users :users_002

    options = { skip_pre_condition: true, project: nil }

    assert_sorted_equal Project.where(Project.allowed_to_condition(user, :view_issues, **options)).ids,
                        user.allowed_project_ids_for(:view_issues, **options)

    # test cache
    assert_sorted_equal Project.where(Project.allowed_to_condition(user, :view_issues, **options)).ids,
                        user.allowed_project_ids_for(:view_issues, **options)
  end

  def test_visible_condition_for
    user = users :users_002

    assert_equal Issue.visible_condition(user),
                 user.visible_condition_for(Issue)

    # test cache
    assert_equal Issue.visible_condition(user),
                 user.visible_condition_for(Issue)
  end

  def test_visible_condition_for_with_skip_pre_condition
    user = users :users_002

    options = { skip_pre_condition: true, project: projects(:projects_001) }

    assert_equal Issue.visible_condition(user, **options),
                 user.visible_condition_for(Issue, **options)

    # test cache
    assert_equal Issue.visible_condition(user, **options),
                 user.visible_condition_for(Issue, **options)
  end

  def test_user_scope_for_anonymous_user
    assert_not_empty User.where(id: 6)
  end
end
