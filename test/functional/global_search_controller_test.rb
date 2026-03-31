# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class GlobalSearchControllerTest < Additionals::ControllerTest
  def setup
    prepare_tests
    Setting.default_language = 'en'
  end

  def test_search_requires_login
    get :search, params: { q: 'test query' }

    assert_response :redirect
  end

  def test_search_short_query_returns_empty
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'a' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert json.key? 'keyword'
    assert json.key? 'semantic'
  end

  def test_search_returns_json
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'Cannot print recipes' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
  end

  def test_search_with_project_scope
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'Cannot print recipes', project_id: 'ecookbook' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
  end

  def test_search_with_invalid_project
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'test query', project_id: 'nonexistent-project' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
  end

  def test_search_with_custom_limit
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'Cannot print recipes', limit: 2 }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
  end

  def test_search_empty_query_returns_empty
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: '' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert json.key? 'keyword'
  end

  def test_search_without_query_returns_empty
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert json.key? 'keyword'
  end

  def test_search_with_types_filter
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'Cannot print recipes', 'types[]': 'issues' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert_kind_of Array, json['keyword']
  end

  def test_search_with_bookmarks_scope
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'test', scope: 'bookmarks' }

    assert_response :success
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert_kind_of Array, json['keyword']
  end
end
