require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < Redmine::RoutingTest
  def test_issue_assign_to_me
    should_route 'PUT /issues/1/assign_to_me' => 'additionals_assign_to_me#update', issue_id: '1'
  end

  def test_issue_change_status
    should_route 'PUT /issues/1/change_status' => 'additionals_change_status#update', issue_id: '1'
  end
end
