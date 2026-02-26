# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Test class to simulate entities that include EntityMethods
class TestEntity
  include Additionals::EntityMethods

  attr_accessor :project, :author, :assigned_to_id_was

  def initialize(project: nil, author: nil, assigned_to_id_was: nil)
    @project = project
    @author = author
    @assigned_to_id_was = assigned_to_id_was
  end

  def new_record?
    true
  end

  def id_previously_changed?
    false
  end

  def visible?(_user = User.current)
    true
  end

  # Minimal journal support for EntityMethods
  def journals
    @journals ||= []
  end

  def init_journal(_user)
    # Stub for testing
  end
end

# Test class to simulate a sensitive entity (like Password) - simplified
class TestSensitiveEntity
  include Additionals::EntityMethods

  attr_accessor :project, :author, :assigned_to_id_was

  def initialize(project: nil, author: nil, assigned_to_id_was: nil)
    @project = project
    @author = author
    @assigned_to_id_was = assigned_to_id_was
  end

  def new_record?
    true
  end

  def id_previously_changed?
    false
  end

  def visible?(_user = User.current)
    true
  end

  def journals
    @journals ||= []
  end

  def init_journal(_user)
    # Stub for testing
  end
end

class EntityMethodsAssignableUsersTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  def test_assignable_users_with_project_performance
    project = projects :projects_001

    # Create sufficient test data to detect N+1 problems (minimum 12 assignable users)
    entity_role = Role.create!(
      name: 'Entity Performance Role',
      assignable: true,
      permissions: %i[view_issues add_issues]
    )

    # Create 12 additional users to have enough data for N+1 detection
    created_users = []
    12.times do |i|
      user = User.create!(
        login: "entityperf#{i}",
        firstname: "EntityPerf#{i}",
        lastname: 'User',
        mail: "entityperf#{i}@example.com",
        status: User::STATUS_ACTIVE
      )
      created_users << user
      Member.create! project: project, principal: user, roles: [entity_role]
    end

    entity = TestEntity.new project: project

    # Test that assignable_users doesn't cause N+1 queries
    # With 12+ assignable users, N+1 problem would show significantly more queries
    queries_before = count_sql_queries { entity.assignable_users }

    # Should use limited number of queries (not N+1)
    # With N+1 problem, this would be 24+ queries (2 per user)
    assert_operator queries_before, :<=, 10, 'EntityMethods#assignable_users should use limited number of queries'

    # Verify we actually have enough test data
    assignable_users = entity.assignable_users

    assert_operator assignable_users.size, :>=, 12, 'Should have at least 12 assignable users for valid N+1 test'
  end

  def test_assignable_users_with_project_and_hidden_roles
    project = projects :projects_001

    # Create a hidden role
    hidden_role = Role.create!(
      name: 'Entity Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues add_issues]
    )

    # Create a user with the hidden role
    user = User.create!(
      login: 'entityhiddenuser',
      firstname: 'EntityHidden',
      lastname: 'User',
      mail: 'entityhidden@example.com',
      status: User::STATUS_ACTIVE
    )

    Member.create! project: project, principal: user, roles: [hidden_role]

    entity = TestEntity.new project: project

    # Regular user should not see users with hidden roles
    regular_user = User.create!(
      login: 'entityregularuser',
      firstname: 'EntityRegular',
      lastname: 'User',
      mail: 'entityregular@example.com',
      status: User::STATUS_ACTIVE
    )

    regular_role = Role.create!(
      name: 'Entity Regular Role',
      permissions: %i[view_project view_issues]
    )

    Member.create! project: project, principal: regular_user, roles: [regular_role]

    User.current = regular_user
    assignable = entity.assignable_users

    assert_not_includes assignable, user, 'User with hidden role should not be visible to regular users'

    # Admin should see all users
    User.current = users :users_001
    assignable_admin = entity.assignable_users

    assert_includes assignable_admin, user, 'Admin should see users with hidden roles'
  end

  def test_assignable_users_without_project_uses_global
    entity = TestEntity.new # No project

    User.current = users :users_001

    # Should fall back to global assignable users
    assignable = entity.assignable_users

    assert_kind_of Array, assignable
    assignable.each { |u| assert_kind_of Principal, u }
  end

  def test_assignable_users_includes_author
    project = projects :projects_001
    author = users :users_002
    entity = TestEntity.new project: project, author: author

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_includes assignable, author, 'Author should always be included in assignable users'
  end

  def test_assignable_users_includes_previous_assignee
    project = projects :projects_001
    previous_assignee = users :users_003
    entity = TestEntity.new project: project, assigned_to_id_was: previous_assignee.id

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_includes assignable, previous_assignee, 'Previous assignee should be included in assignable users'
  end

  def test_assignable_users_with_author_and_previous_assignee
    project = projects :projects_001
    author = users :users_002
    previous_assignee = users :users_003
    entity = TestEntity.new(
      project: project,
      author: author,
      assigned_to_id_was: previous_assignee.id
    )

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_includes assignable, author, 'Author should be included'
    assert_includes assignable, previous_assignee, 'Previous assignee should be included'

    # Should not have duplicates
    assert_equal assignable.size, assignable.uniq.size, 'Should not contain duplicate users'
  end

  def test_assignable_users_returns_sorted_array
    project = projects :projects_001
    entity = TestEntity.new project: project

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_kind_of Array, assignable
    assert_equal assignable, assignable.sort, 'Assignable users should be sorted'
  end

  def test_assignable_users_respects_active_status
    project = projects :projects_001

    # Create an inactive user with assignable role
    inactive_user = User.create!(
      login: 'inactiveuser',
      firstname: 'Inactive',
      lastname: 'User',
      mail: 'inactive@example.com',
      status: User::STATUS_LOCKED # Inactive
    )

    assignable_role = roles :roles_002
    Member.create! project: project, principal: inactive_user, roles: [assignable_role]

    entity = TestEntity.new project: project

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_not_includes assignable, inactive_user, 'Inactive users should not be in assignable users'
  end

  def test_assignable_users_with_inactive_author
    project = projects :projects_001

    # Create an inactive author
    inactive_author = User.create!(
      login: 'inactiveauthor',
      firstname: 'Inactive',
      lastname: 'Author',
      mail: 'inactiveauthor@example.com',
      status: User::STATUS_LOCKED # Inactive
    )

    entity = TestEntity.new project: project, author: inactive_author

    User.current = users :users_001
    assignable = entity.assignable_users

    assert_not_includes assignable, inactive_author, 'Inactive author should not be included'
  end

  def test_assignable_users_explicit_project_parameter
    project = projects :projects_001
    other_project = projects :projects_002

    entity = TestEntity.new project: project

    User.current = users :users_001

    # Test with explicit project parameter
    assignable_explicit = entity.assignable_users other_project
    assignable_default = entity.assignable_users

    # Should use the explicit project, not the entity's project
    # This is mainly to test the parameter handling
    assert_kind_of Array, assignable_explicit
    assert_kind_of Array, assignable_default

    assignable_explicit.each { |u| assert_kind_of Principal, u }
    assignable_default.each { |u| assert_kind_of Principal, u }
  end

  def test_assignable_users_performance_compared_to_original
    project = projects :projects_001
    entity = TestEntity.new project: project

    User.current = users :users_001

    # Test optimized version
    queries_optimized = count_sql_queries { entity.assignable_users }

    # Should use reasonable number of queries
    assert_operator queries_optimized, :<=, 10, 'Optimized version should use limited queries'
  end

  def test_simplified_entity_assignable_users
    # Test that entities work without permission constants
    entity = TestEntity.new project: projects(:projects_001)
    assignable = entity.assignable_users

    assert_kind_of Array, assignable
    assignable.each { |u| assert_kind_of Principal, u }
  end

  # ==========================================
  # CRITICAL: Entity Group Assignment Tests
  # ==========================================
  # These tests verify that EntityMethods.assignable_users ALWAYS includes groups,
  # regardless of Setting.issue_group_assignment?
  #
  # This is intentional and different from Issue behavior!
  # Custom entities (Password, etc.) need group assignment independently of the
  # Redmine issue setting. A user may disable group assignment for issues but
  # still want to assign entities to groups for access control.

  def test_assignable_users_always_includes_groups_regardless_of_setting
    project = projects :projects_001

    # Create a group with assignable role
    group = Group.create! lastname: 'Entity Test Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Entity Group Test Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    entity = TestEntity.new project: project
    User.current = users :users_001

    # CRITICAL TEST: Even when issue_group_assignment is DISABLED,
    # entity assignable_users should STILL include groups
    with_settings issue_group_assignment: '0' do
      assignable = entity.assignable_users

      groups = assignable.grep Group
      users = assignable.grep User

      assert users.any?, 'Should include users'
      assert groups.any?, 'CRITICAL: Entity assignable_users should include groups even when issue_group_assignment is disabled'
      assert_includes groups, group, 'Created group should be in entity assignable users'
    end

    # Also verify it works when setting is enabled
    with_settings issue_group_assignment: '1' do
      assignable = entity.assignable_users

      groups = assignable.grep Group

      assert groups.any?, 'Should include groups when issue_group_assignment is enabled'
      assert_includes groups, group
    end
  end

  def test_entity_vs_issue_group_assignment_difference
    project = projects :projects_001

    # Create a group with assignable role
    group = Group.create! lastname: 'Comparison Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Comparison Test Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    entity = TestEntity.new project: project
    User.current = users :users_001

    with_settings issue_group_assignment: '0' do
      # Entity should include groups
      entity_assignable = entity.assignable_users
      entity_groups = entity_assignable.grep Group

      # Issue method should NOT include groups
      issue_assignable = Additionals::AssignableUsersOptimizer.project_assignable_users project
      issue_groups = issue_assignable.grep Group

      assert entity_groups.any?, 'Entity should include groups when setting is disabled'
      assert_empty issue_groups, 'Issue method should NOT include groups when setting is disabled'

      # This demonstrates the intentional difference
      assert_includes entity_groups, group, 'Group should be in entity assignables'
      assert_not_includes issue_groups, group, 'Group should NOT be in issue assignables'
    end
  end

  def test_sensitive_entity_always_includes_groups
    # Test with a "sensitive" entity type (like Password)
    project = projects :projects_001

    group = Group.create! lastname: 'Sensitive Entity Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Sensitive Entity Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    entity = TestSensitiveEntity.new project: project
    User.current = users :users_001

    with_settings issue_group_assignment: '0' do
      assignable = entity.assignable_users

      groups = assignable.grep Group

      assert groups.any?, 'Sensitive entity should include groups for access control'
      assert_includes groups, group
    end
  end

  def test_assignable_users_groups_with_hidden_roles
    project = projects :projects_001

    # Create a hidden role with a group
    hidden_role = Role.create!(
      name: 'Entity Group Hidden Role',
      assignable: true,
      hide: true,
      users_visibility: 'members_of_visible_projects',
      permissions: %i[view_issues]
    )

    hidden_group = Group.create! lastname: 'Hidden Entity Group'
    Member.create! project: project, principal: hidden_group, roles: [hidden_role]

    entity = TestEntity.new project: project

    # Regular user should not see groups with hidden roles
    regular_user = User.create!(
      login: 'grouphiddenregular',
      firstname: 'GroupHiddenRegular',
      lastname: 'User',
      mail: 'grouphiddenregular@example.com',
      status: User::STATUS_ACTIVE
    )

    User.current = regular_user
    assignable = entity.assignable_users

    assert_not_includes assignable, hidden_group, 'Group with hidden role should not be visible to regular users'

    # Admin should see the group
    User.current = users :users_001
    assignable_admin = entity.assignable_users

    assert_includes assignable_admin, hidden_group, 'Admin should see groups with hidden roles'
  end

  def test_global_assignable_users_includes_groups
    entity = TestEntity.new # No project - uses global

    # Create a group with assignable role in some project
    project = projects :projects_001
    group = Group.create! lastname: 'Global Entity Group'
    assignable_role = Role.find_by(assignable: true) || Role.create!(
      name: 'Global Entity Role',
      assignable: true,
      permissions: %i[view_issues]
    )
    Member.create! project: project, principal: group, roles: [assignable_role]

    User.current = users :users_001

    with_settings issue_group_assignment: '0' do
      assignable = entity.assignable_users

      groups = assignable.grep Group

      assert groups.any?, 'Global entity assignable should include groups even when issue_group_assignment is disabled'
    end
  end
end
