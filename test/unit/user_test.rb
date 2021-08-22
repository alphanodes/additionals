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
    skip 'Skip redmine_sudo test, because redmine_contacts is not installed' unless Redmine::Plugin.installed? 'redmine_sudo'

    user = users :users_001
    user.sudoer = true
    user.save!
    user.reload

    assert user.sudoer
    assert user.admin
    assert User.where(sudoer: true).first.can_be_admin?

    user.admin = false
    user.save!
    user.reload

    assert user.sudoer
    assert_not user.admin
    assert User.where(sudoer: true).first.can_be_admin?
  end

  def test_non_sudoer_without_admin_can_not_be_admin
    skip 'Skip redmine_sudo test, because redmine_contacts is not installed' unless Redmine::Plugin.installed? 'redmine_sudo'

    assert_not User.where(sudoer: false, admin: false).first.can_be_admin?
  end
end
