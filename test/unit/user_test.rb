require File.expand_path('../../test_helper', __FILE__)

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
    admin_user = User.generate!(admin: true)

    users = User.visible.active.with_permission(:save_dashboards)
    assert_equal 5, users.count
    assert users.exists?(id: admin_user)
  end

  def test_with_permission_on_project
    assert_equal 3, User.visible.active.with_permission(:save_dashboards, projects(:projects_001)).count
  end
end
