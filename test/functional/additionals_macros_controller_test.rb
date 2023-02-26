# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsMacrosControllerTest < Additionals::ControllerTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :enabled_modules

  def setup
    prepare_tests
  end

  def test_show
    @request.session[:user_id] = 2
    get :show

    assert_response :success
    assert_select 'div.macro-box'
  end

  def test_show_no_allowed_for_guests
    @request.session[:user_id] = nil
    get :show

    assert_response :redirect
  end
end
