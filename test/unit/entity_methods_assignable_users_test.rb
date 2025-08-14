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
    entity = TestEntity.new project: project

    # Test that assignable_users doesn't cause N+1 queries
    queries_before = count_sql_queries { entity.assignable_users }

    # Should use limited number of queries (not N+1)
    assert_operator queries_before, :<=, 10, 'EntityMethods#assignable_users should use limited number of queries'
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
end
