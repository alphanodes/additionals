# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsAssignToMeControllerTest < Additionals::ControllerTest
  test 'assign issue to user' do
    session[:user_id] = 2
    assert_difference 'Journal.count' do
      put :update,
          params: { issue_id: 1 }
    end
  end

  test 'no update for issue, which already same user is assigned' do
    session[:user_id] = 3
    assert_no_difference 'Journal.count' do
      put :update,
          params: { issue_id: 2 }
    end
  end
end
