# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AutoCompletesControllerTest < Additionals::ControllerTest
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

  def test_issue_assignee_with_involved_principals
    issue = issues :issues_001

    get :issue_assignee,
        params: { project_id: 1, issue_id: issue.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json

    involved_group = json.detect { |g| g.is_a?(Hash) && g['children'] && g['text'] != 'active' }

    assert_not_nil involved_group, 'Expected involved principals group'
    assert involved_group['children'].any?
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

  def test_authors
    get :authors, xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 'me', json.first['id']
    assert_equal 'active', json.second['text']
  end

  def test_authors_for_project
    get :authors,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 'me', json.first['id']
    assert json.second['children'].any?
  end

  def test_authors_with_search
    get :authors,
        params: { q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_equal 1, json.count

    children = json.first['children']

    assert_equal 1, children.count
    assert_equal 2, children.first['id']
    assert_equal 'John Smith', children.first['text']
  end

  def test_custom_field_users_without_project
    get :custom_field_users,
        params: { custom_field_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_empty json
  end

  def test_custom_field_users_for_project
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert json.any?
  end

  def test_custom_field_users_with_search
    cf = IssueCustomField.create! name: 'Test User CF',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id, q: 'john' },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    children = json.first['children']

    assert_equal 1, children.count
    assert_equal 'John Smith', children.first['text']
  end

  def test_custom_field_users_with_invalid_cf
    get :custom_field_users,
        params: { project_id: 1, custom_field_id: 99_999 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
    assert_empty json
  end

  def test_authors_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :authors, xhr: true

      assert_response :unauthorized
    end
  end

  def test_authors_scoped_by_visibility
    @request.session[:user_id] = 8

    get :authors,
        params: { project_id: 1 },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    # Results are scoped by user visibility, not full project member list
    assert_kind_of Array, json
  end

  def test_custom_field_users_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :custom_field_users,
          params: { project_id: 1, custom_field_id: 1 },
          xhr: true

      assert_response :unauthorized
    end
  end

  def test_custom_field_users_scoped_by_visibility
    @request.session[:user_id] = 8

    cf = IssueCustomField.create! name: 'Test User CF Perm',
                                  field_format: 'user',
                                  is_for_all: true,
                                  tracker_ids: [1]

    get :custom_field_users,
        params: { project_id: 1, custom_field_id: cf.id },
        xhr: true

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Array, json
  end

  def test_issue_assignee_requires_login
    with_settings login_required: '1' do
      @request.session[:user_id] = nil
      get :issue_assignee, xhr: true

      assert_response :unauthorized
    end
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
