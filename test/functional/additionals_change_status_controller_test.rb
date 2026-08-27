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

  test 'redirect to journal of status change' do
    session[:user_id] = 2
    issue = issues :issues_004

    put :update,
        params: { issue_id: issue.id, new_status_id: 3 }

    journal = issue.reload.journals.visible.order(:created_on).last

    assert_redirected_to "#{issue_path issue}#change-#{journal.id}"
  end

  test 'no update for issue, which already has same status' do
    session[:user_id] = 2
    assert_no_difference 'Journal.count' do
      put :update,
          params: { issue_id: 2, new_status_id: 2 }
    end
  end
end
