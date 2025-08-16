# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AssignableUsersPerformanceComparisonTest < Additionals::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :trackers, :workflows

  def setup
    @project = projects :projects_001
    User.current = users :users_002
  end

  def test_performance_comparison_no_caching_vs_multiple_calls
    # Test shows that even without caching, we still have good performance
    # because ActiveRecord relations are lazy-loaded

    query_count_before = count_queries do
      # First call - this executes the query
      result1 = @project.assignable_users
      _users1 = result1.to_a
    end

    query_count_after = count_queries do
      # Second call - this creates a new relation and executes again
      result2 = @project.assignable_users
      _users2 = result2.to_a
    end

    # Both calls should use similar number of queries (no caching benefit)
    assert_operator query_count_before, :<=, 10, 'First call should be efficient'
    assert_operator query_count_after, :<=, 10, 'Second call should be efficient'

    puts "First call: #{query_count_before} queries"
    puts "Second call: #{query_count_after} queries"
    puts 'No caching, but still efficient due to optimized queries!'
  end

  def test_chaining_performance_benefit
    # The real benefit: multiple .where() calls on the same relation are efficient

    query_count = count_queries do
      base_relation = @project.assignable_users

      # These operations are lazy - no queries executed yet
      users_only = base_relation.where type: 'User'
      first_5 = users_only.limit 5
      ordered = first_5.order :firstname

      # Only now the query executes - and it's a single optimized query
      _final_result = ordered.to_a
    end

    assert_operator query_count, :<=, 10, 'Chained operations should be efficient'
    puts "Chained operations used #{query_count} queries - this is the real benefit!"
  end

  def test_backward_compatibility_performance
    # Test the exact pattern from redmine_servicedesk
    query_count = count_queries do
      # This is exactly what redmine_servicedesk does
      result = @project.assignable_users.where(type: 'User').map { |t| [t.name, t.id] }

      assert_kind_of Array, result, 'Should return array after map'
    end

    assert_operator query_count, :<=, 10, 'Backward compatibility should be efficient'
    puts "redmine_servicedesk pattern used #{query_count} queries"
  end

  private

  def count_queries(&)
    query_count = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      query_count += 1 unless payload[:name] == 'SCHEMA'
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    query_count
  end
end
