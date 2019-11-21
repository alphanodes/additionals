require File.expand_path('../../test_helper', __FILE__)

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
      project = Project.find(5)
      assert_equal project.assignable_users.count, project.assignable_users_and_groups.count
    end
    with_settings issue_group_assignment: '0' do
      project = Project.find(5)
      assert_not_equal project.assignable_users.count, project.assignable_users_and_groups.count
    end
  end

  def test_visible_users
    project = projects(:projects_005)
    assert_equal 3, project.visible_users.count
  end

  def test_visible_principals
    project = projects(:projects_005)
    assert_equal 4, project.visible_principals.count
  end
end
