# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AutoCompletesControllerTest < Additionals::ControllerTest
  fixtures :projects, :email_addresses,
           :enumerations, :users, :groups_users,
           :roles,
           :members, :member_roles,
           :enabled_modules

  def test_fontawesome_default
    get :fontawesome

    assert_response :success
    json = ActiveSupport::JSON.decode response.body
    assert_kind_of Array, json
    icon = json.first
    assert_kind_of Hash, icon
    assert_equal 'far_address-book', icon['id']
    assert_equal 'Address Book', icon['text']
  end

  def test_fontawesome_search
    get :fontawesome,
        params: { q: 'sun' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body
    assert_kind_of Array, json
    assert_equal 5, json.count
    icon = json.first
    assert_kind_of Hash, icon
    assert_equal 'fas_cloud-sun', icon['id']
    assert_equal 'Cloud with Sun', icon['text']
  end

  def test_fontawesome_search_without_result
    get :fontawesome,
        params: { q: 'doesnotexist' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body
    assert_kind_of Array, json
    assert_equal 0, json.count
  end
end
