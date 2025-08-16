# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AssignableUsersBackwardCompatibilityTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :trackers, :workflows

  def setup
    @project = projects :projects_001
    User.current = users :users_002
  end

  def test_assignable_users_returns_activerecord_relation
    result = @project.assignable_users

    assert_kind_of ActiveRecord::Relation, result,
                   "assignable_users should return ActiveRecord::Relation, got #{result.class}"
  end

  def test_assignable_users_supports_where_method
    # This test simulates what redmine_servicedesk does: @project.assignable_users.where(type: 'User')
    result = @project.assignable_users.where type: 'User'

    assert_kind_of ActiveRecord::Relation, result,
                   "assignable_users.where() should return ActiveRecord::Relation, got #{result.class}"

    # Should only contain Users, not Groups
    result.each do |user|
      assert_equal 'User', user.type, "Expected only Users, found #{user.type}"
    end
  end

  def test_assignable_users_with_tracker_returns_activerecord_relation
    tracker = trackers :trackers_001
    result = @project.assignable_users tracker

    assert_kind_of ActiveRecord::Relation, result,
                   "assignable_users(tracker) should return ActiveRecord::Relation, got #{result.class}"
  end

  def test_assignable_users_with_tracker_supports_where_method
    tracker = trackers :trackers_001
    result = @project.assignable_users(tracker).where(type: 'User')

    assert_kind_of ActiveRecord::Relation, result,
                   "assignable_users(tracker).where() should return ActiveRecord::Relation, got #{result.class}"

    # Should only contain Users, not Groups
    result.each do |user|
      assert_equal 'User', user.type, "Expected only Users, found #{user.type}"
    end
  end

  def test_assignable_users_supports_other_activerecord_methods
    # Test other common ActiveRecord methods that dependent plugins might use
    result = @project.assignable_users

    # These should all work without errors
    assert_respond_to result, :count
    assert_respond_to result, :first
    assert_respond_to result, :last
    assert_respond_to result, :pluck
    assert_respond_to result, :limit
    assert_respond_to result, :order

    # Test actual execution
    count = result.count

    assert_operator count, :>=, 0, 'count should work'

    skip unless count.positive?

    first_user = result.first

    assert_kind_of Principal, first_user, 'first() should return a Principal'
  end

  def test_assignable_users_backward_compatibility_with_redmine_servicedesk_pattern
    # Exact pattern from redmine_servicedesk: @project.assignable_users.where(type: 'User').map { |t| [t.name, t.id] }
    result = @project.assignable_users.where(type: 'User').map { |t| [t.name, t.id] }

    assert_kind_of Array, result, 'Final result should be an Array after map'

    result.each do |name_id_pair|
      assert_kind_of Array, name_id_pair, 'Each element should be an array'
      assert_equal 2, name_id_pair.length, 'Each element should have [name, id]'
      assert_kind_of String, name_id_pair[0], 'Name should be a string'
      assert_kind_of Integer, name_id_pair[1], 'ID should be an integer'
    end
  end
end
