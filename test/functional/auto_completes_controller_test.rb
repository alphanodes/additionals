# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AutoCompletesControllerTest < Additionals::ControllerTest
  fixtures :projects, :email_addresses,
           :enumerations, :users, :groups_users,
           :roles,
           :members, :member_roles,
           :enabled_modules

  def setup
    prepare_tests
    Setting.default_language = 'en'
  end

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

  def test_issue_assignee
    with_settings issue_group_assignment: '0' do
      get :issue_assignee, xhr: true

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_kind_of Array, json
      assert_equal 2, json.count

      assert_equal 'me', json.first['id']
      assert_equal 'active', json.second['text']
      assert_equal 4, json.second['children'].count
    end
  end

  def test_assignee
    get :assignee, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 3, json.count

    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
    assert_equal 'Groups', json.third['text']
    assert_equal 2, json.third['children'].count
  end

  def test_grouped_principals
    get :grouped_principals, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
    assert_equal 'Groups', json.second['text']
    assert_equal 2, json.second['children'].count
  end

  def test_grouped_principals_with_me
    get :grouped_principals,
        params: { with_me: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json

    assert_equal 3, json.count
    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
    assert_equal 'Groups', json.third['text']
    assert_equal 2, json.third['children'].count
  end

  def test_grouped_users
    get :grouped_users, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
  end

  def test_grouped_users_with_me
    get :grouped_users,
        params: { with_me: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
    assert_equal 7, json.second['children'].count
  end

  def test_grouped_users_with_ano
    get :grouped_users,
        params: { with_ano: true },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 2, json.count

    assert_equal 'active', json.first['text']
    assert_equal 7, json.first['children'].count
    assert_equal 'Anonymous', json.second['text']
  end

  def test_grouped_users_for_project
    get :grouped_users,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 2, json.first['children'].count
  end

  def test_grouped_users_with_excluded_user
    get :grouped_users,
        params: { user_id: 2 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 6, json.first['children'].count
    assert_not(json.first['children'].detect { |u| u['id'] == 2 })
  end

  def test_grouped_users_with_search
    get :grouped_users,
        params: { q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    children = json.first['children']

    assert_equal 1, children.count

    entry = children.first

    assert_equal 2, entry['id']
    assert_equal 'John Smith', entry['text']
    assert_equal 'John Smith', entry['name']
    assert_equal 2, entry['value']
  end

  def test_grouped_users_scope
    Role.anonymous.update! users_visibility: 'members_of_visible_projects'
    @request.session[:user_id] = nil
    get :grouped_users, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    assert_equal 'active', json.first['text']
    assert_equal 2, json.first['children'].count
  end
end
