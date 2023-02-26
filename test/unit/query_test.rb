# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class QueryTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :roles,
           :repositories

  def setup
    User.current = nil
  end

  def test_issue_query_principals_with_hide
    prepare_query_tests
    User.current = @user_with_hide
    query = IssueQuery.new project: @project, name: '_'

    # show all members + current user of hidden role
    assert_equal 3, query.principals.count
  end

  def test_issue_query_principals_with_show_hide_permission
    prepare_query_tests
    User.current = @user_with_show_hide
    query = IssueQuery.new project: @project, name: '_'

    # show all members with 2 users of hidden role
    assert_equal 4, query.principals.count
  end

  private

  def prepare_query_tests
    @role1 = Role.new name: 'principal test hide1', users_visibility: 'members_of_visible_projects', hide: true
    @role1.add_permission! 'view_issues'
    @role1.save!

    @role2 = Role.new name: 'principal test hide2', users_visibility: 'members_of_visible_projects', hide: true
    @role2.add_permission! 'view_issues', 'show_hidden_roles_in_memberbox'
    @role2.save!

    @project = projects :projects_001

    @user_with_hide = User.generate! firstname: 'hide1', lastname: 'role'
    m = Member.new user_id: @user_with_hide.id, project_id: @project.id
    m.member_roles.build role_id: @role1.id
    m.save!

    @user_with_show_hide = User.generate! firstname: 'hide2', lastname: 'role'
    m = Member.new user_id: @user_with_show_hide.id, project_id: @project.id
    m.member_roles.build role_id: @role2.id
    m.save!
  end
end
