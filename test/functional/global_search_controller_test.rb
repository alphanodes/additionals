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
    assert json.key? 'jump'
  end

  # The dialog builds its tabs from these counts
  def test_search_reports_the_hit_count_of_every_type
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    get :search, params: { q: 'Cannot print recipes' }

    counts = ActiveSupport::JSON.decode(response.body)['counts']

    assert_kind_of Hash, counts
    assert_operator counts['issues'].to_i, :>, 0
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

  def test_search_returns_json_error_on_exception
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    GlobalSearch.define_singleton_method :original_search, GlobalSearch.method(:search)
    GlobalSearch.define_singleton_method(:search) { |*| raise StandardError, 'Something went wrong' }

    get :search, params: { q: 'test query' }

    assert_response :internal_server_error
    json = ActiveSupport::JSON.decode response.body

    assert_kind_of Hash, json
    assert json.key?('error'), 'Response should contain error key'
    assert_includes json['error'], 'Something went wrong'
  ensure
    if GlobalSearch.respond_to? :original_search
      GlobalSearch.define_singleton_method :search, GlobalSearch.method(:original_search)
      GlobalSearch.singleton_class.remove_method :original_search
    end
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

  def test_semantic_requires_login
    get :semantic, params: { q: 'test query' }

    assert_response :redirect
  end

  def test_semantic_returns_provider_results
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    with_semantic_provider do |provider|
      get :semantic, params: { q: 'Cannot print recipes', project_id: 'ecookbook', 'types[]': 'issues' }

      assert_response :success
      json = ActiveSupport::JSON.decode response.body

      assert_equal ['/issues/1'], json['results'].pluck('url')
      assert_equal ['issues'], provider.last_types
      assert_equal projects(:projects_001), provider.last_project
    end
  end

  def test_semantic_passes_the_search_scope
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    with_semantic_provider do |provider|
      get :semantic, params: { q: 'Cannot print recipes', scope: 'bookmarks' }

      assert_equal Project.listable.where(id: users(:users_002).bookmarked_project_ids).to_sql,
                   provider.last_projects.to_sql
    end
  end

  def test_semantic_with_short_query_asks_no_provider
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    with_semantic_provider do |provider|
      get :semantic, params: { q: 'a' }

      assert_response :success
      assert_empty ActiveSupport::JSON.decode(response.body)['results']
      assert_equal 0, provider.calls
    end
  end

  def test_semantic_skips_a_number_without_keyword_hits
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    with_semantic_provider do |provider|
      get :semantic, params: { q: '2026' }

      assert_equal 0, provider.calls
    end
  end

  def test_semantic_asks_for_a_number_with_keyword_hits
    session[:user_id] = 2
    @request.headers['Accept'] = 'application/json'

    with_semantic_provider do |provider|
      get :semantic, params: { q: '2026', keyword_hits: '3' }

      assert_equal 1, provider.calls
    end
  end

  private

  def with_semantic_provider
    provider = Class.new do
      class << self
        attr_accessor :calls, :last_types, :last_project, :last_projects

        def search(*, project: nil, projects: nil, types: nil, **)
          self.calls += 1
          self.last_types = types
          self.last_project = project
          self.last_projects = projects
          [{ id: 1, title: 'Semantic hit', url: '/issues/1', type: 'Issues' }]
        end

        def label = :label_search
        def permission = nil
      end
    end
    provider.calls = 0

    original_providers = GlobalSearch.providers.dup
    GlobalSearch.providers.replace [provider]
    yield provider
  ensure
    GlobalSearch.providers.replace original_providers
  end
end
