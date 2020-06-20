require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < Redmine::RoutingTest
  def test_issue_assign_to_me
    should_route 'PUT /issues/1/assign_to_me' => 'additionals_assign_to_me#update', issue_id: '1'
  end

  def test_issue_change_status
    should_route 'PUT /issues/1/change_status' => 'additionals_change_status#update', issue_id: '1'
  end

  def test_help_macro
    should_route 'GET /help/macros' => 'additionals_macros#show'
  end

  def test_auto_completes
    should_route 'GET /auto_completes/fontawesome' => 'auto_completes#fontawesome'
    should_route 'GET /auto_completes/issue_assignee' => 'auto_completes#issue_assignee'
  end
end
