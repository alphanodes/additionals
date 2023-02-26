# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdminControllerTest < Additionals::ControllerTest
  fixtures :users, :email_addresses, :roles

  def setup
    User.current = nil
    @request.session[:user_id] = 1
  end

  def test_info
    get :info

    assert_response :success
    assert_select 'table.list tr.system_info'
  end
end
