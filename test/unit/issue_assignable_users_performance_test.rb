# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Test to verify Issue assignable_users with tracker doesn't cause N+1 queries
class IssueAssignableUsersPerformanceTest < Additionals::TestCase
  def setup
    prepare_tests
    User.current = nil
  end

  def teardown
    User.current = nil
  end

  def test_issue_assignable_users_with_tracker_no_n_plus_one
    project = projects :projects_001
    tracker = project.trackers.order(:id).first

    User.current = users :users_001

    # This should NOT cause N+1 queries in the tracker workflow filtering
    queries_count = count_sql_queries do
      # This is what issues#new controller does - calls assignable_users with tracker
      assignable_users = project.assignable_users tracker

      # Access user attributes like the controller would for select options
      assignable_users.each do |user|
        user.name # This should not trigger additional queries
        user.login
      end
    end

    # Should use limited number of queries, not N+1 based on user count
    # Original N+1 problem: 2 queries per user (role lookup + workflow check)
    # Optimized version: should be ≤15 total queries regardless of user count
    assert_operator queries_count, :<=, 15,
                    'Issue assignable_users with tracker should not cause N+1 queries'
  end

  def test_issue_assignable_users_workflow_filtering_works
    project = projects :projects_001
    tracker = project.trackers.order(:id).first

    User.current = users :users_001

    # Get assignable users with tracker filtering
    users_with_tracker = project.assignable_users tracker
    users_without_tracker = project.assignable_users # No tracker

    assert_kind_of ActiveRecord::Relation, users_with_tracker
    assert_kind_of ActiveRecord::Relation, users_without_tracker

    # Both should return users
    assert users_with_tracker.any?, 'Should have some assignable users with tracker'
    assert users_without_tracker.any?, 'Should have some assignable users without tracker'

    # Tracker filtering might reduce the list (depending on workflow setup)
    assert_operator users_with_tracker.size, :<=, users_without_tracker.size,
                    'Tracker filtering should not increase user count'

    # All returned users should be valid
    users_with_tracker.each { |u| assert_kind_of Principal, u }
    users_without_tracker.each { |u| assert_kind_of Principal, u }
  end

  def test_issue_assignable_users_performance_focus
    project = projects :projects_001
    tracker = project.trackers.order(:id).first

    User.current = users :users_001

    # Focus on performance - the hidden roles functionality is already tested elsewhere
    # This test specifically targets the N+1 problem in workflow filtering
    queries_count = count_sql_queries do
      # Multiple calls to test caching behavior
      users1 = project.assignable_users tracker
      users2 = project.assignable_users tracker # Should use cache

      users1.each(&:name)
      users2.each(&:login)
    end

    # Second call should be cached, so total queries should be minimal
    assert_operator queries_count, :<=, 10,
                    'Multiple calls with same tracker should use caching effectively'

    # Test that results are consistent
    users1 = project.assignable_users tracker
    users2 = project.assignable_users tracker

    assert_equal users1, users2, 'Cached results should be identical'
    assert users1.all?(Principal), 'All results should be Principal objects'
  end

  def test_issue_assignable_users_with_multiple_trackers
    project = projects :projects_001
    trackers = project.trackers.limit 2

    User.current = users :users_001

    # Test that different trackers can have different assignable users
    # This should not cause multiplicative N+1 problems
    total_queries = 0

    trackers.each do |tracker|
      queries_for_tracker = count_sql_queries do
        assignable = project.assignable_users tracker
        assignable.each(&:name) # Access attributes
      end

      total_queries += queries_for_tracker

      # Each tracker call should use limited queries
      assert_operator queries_for_tracker, :<=, 15,
                      "Tracker #{tracker.name} should use limited queries"
    end
  end
end
