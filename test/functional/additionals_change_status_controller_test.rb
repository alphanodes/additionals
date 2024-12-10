# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsChangeStatusControllerTest < Additionals::ControllerTest
  test 'assign new status to issue' do
    session[:user_id] = 2
    assert_difference 'Journal.count' do
      put :update,
          params: { issue_id: 4, new_status_id: 3 }
    end
  end

  test 'no update for issue, which already has same status' do
    session[:user_id] = 2
    assert_no_difference 'Journal.count' do
      put :update,
          params: { issue_id: 2, new_status_id: 2 }
    end
  end
end
