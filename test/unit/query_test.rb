# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class QueryTest < Additionals::TestCase
  def setup
    User.current = nil
  end

  # sql_aggr and sql_aggr_filtered tests
  #
  # sql_aggr: Simple aggregation for counting ALL items in a table
  # sql_aggr_filtered: Filtered aggregation with required sub_query (WHERE clause)
  #
  # When filtering for count = 0, the operator is converted to '!*' (NOT IN).
  # - sql_aggr: Uses simple "table WHERE" for !* operator
  # - sql_aggr_filtered: Preserves "sub_query AND" for !* operator
  #
  # Example: Finding projects with 0 OPEN issues
  # - sql_aggr: Would find projects with NO issues at all (wrong for filtered counts!)
  # - sql_aggr_filtered: Finds projects with no open issues (correct!)

  def test_sql_aggr_uses_simple_table_for_not_in_operator
    query = IssueQuery.new name: '_'

    sql = query.send :sql_aggr,
                     table: Issue.table_name,
                     group_field: 'project_id',
                     operator: '!*',
                     values: ['0']

    # sql_aggr uses simple "table WHERE" for !* operator
    assert_includes sql, "#{Issue.table_name} WHERE",
                    'sql_aggr should use simple table WHERE for !* operator'
  end

  def test_sql_aggr_filtered_preserves_subquery_for_not_in_operator
    query = IssueQuery.new name: '_'

    sql = query.send :sql_aggr_filtered,
                     table: Issue.table_name,
                     group_field: 'project_id',
                     operator: '!*',
                     values: ['0'],
                     sub_query: "#{Issue.table_name} WHERE #{Issue.table_name}.status_id = 999"

    # sql_aggr_filtered preserves the full sub_query with WHERE clause
    assert_includes sql, 'status_id = 999',
                    'sql_aggr_filtered should preserve sub_query filters for !* operator'
  end

  def test_sql_aggr_converts_equals_zero_to_not_in
    query = IssueQuery.new name: '_'

    sql = query.send :sql_aggr,
                     table: Issue.table_name,
                     group_field: 'project_id',
                     operator: '=',
                     values: ['0']

    # When operator is '=' and value is 0, it's converted to NOT IN for performance
    assert_includes sql, 'NOT IN',
                    'Operator = with value 0 should be converted to NOT IN'
  end

  def test_sql_aggr_equals_non_zero_uses_having
    query = IssueQuery.new name: '_'

    sql = query.send :sql_aggr,
                     table: Issue.table_name,
                     group_field: 'project_id',
                     operator: '=',
                     values: ['5']

    # Non-zero values use HAVING COUNT
    assert_includes sql, 'HAVING COUNT',
                    'Non-zero values should use HAVING COUNT'
    assert_includes sql, '= 5',
                    'Should compare to the specified value'
  end

  def test_sql_aggr_filtered_preserves_subquery_for_any_operator
    query = IssueQuery.new name: '_'

    sql = query.send :sql_aggr_filtered,
                     table: Issue.table_name,
                     group_field: 'project_id',
                     operator: '*',
                     values: [''],
                     sub_query: "#{Issue.table_name} WHERE #{Issue.table_name}.status_id = 1"

    # The * (any) operator should preserve sub_query filters
    assert_includes sql, 'status_id = 1',
                    'sql_aggr_filtered should preserve sub_query filters for * operator'
    assert_not_includes sql, 'NOT IN',
                        '* operator should use IN, not NOT IN'
  end

  def test_sql_aggr_filtered_requires_sub_query_argument
    # sql_aggr_filtered has sub_query as a required keyword argument
    # This is enforced by Ruby's keyword argument syntax, no runtime check needed
    query = IssueQuery.new name: '_'

    assert_raises ArgumentError do
      query.send :sql_aggr_filtered,
                 table: Issue.table_name,
                 group_field: 'project_id',
                 operator: '!*',
                 values: ['0']
    end
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

    assert_save @role1

    @role2 = Role.new name: 'principal test hide2', users_visibility: 'members_of_visible_projects', hide: true
    @role2.add_permission! 'view_issues', 'show_hidden_roles_in_memberbox'

    assert_save @role2

    @project = projects :projects_001

    @user_with_hide = User.generate! firstname: 'hide1', lastname: 'role'
    m = Member.new user_id: @user_with_hide.id, project_id: @project.id
    m.member_roles.build role_id: @role1.id

    assert_save m

    @user_with_show_hide = User.generate! firstname: 'hide2', lastname: 'role'
    m = Member.new user_id: @user_with_show_hide.id, project_id: @project.id
    m.member_roles.build role_id: @role2.id

    assert_save m
  end
end
