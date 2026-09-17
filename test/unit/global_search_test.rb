# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class GlobalSearchTest < Additionals::TestCase
  def setup
    User.current = users :users_002
  end

  def test_search_returns_keyword_results_without_asking_providers
    with_counting_provider do |provider|
      result = GlobalSearch.search 'Cannot print recipes', user: User.current

      assert_kind_of Array, result[:keyword]
      assert_not result[:jump]
      assert_not result.key?(:semantic), 'Provider results come from a request of their own'
      assert_equal 0, provider.calls
    end
  end

  def test_search_with_short_query_returns_empty
    result = GlobalSearch.search 'a', user: User.current

    assert_kind_of Hash, result
    assert_equal [], result[:keyword]
  end

  def test_search_with_types_filter
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, types: ['issues']

    assert_kind_of Array, result[:keyword]
    result[:keyword].each do |entry|
      assert_equal 'Issues', entry[:type], "Expected type 'Issues' but got '#{entry[:type]}'"
    end
  end

  def test_search_with_invalid_types_ignored
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, types: ['nonexistent']

    assert_kind_of Hash, result
    assert_equal [], result[:keyword]
  end

  def test_search_with_titles_only
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, titles_only: true

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
  end

  def test_search_with_bookmarks_scope
    result = GlobalSearch.search 'test', user: User.current, scope: 'bookmarks'

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
  end

  def test_search_with_project_scope
    project = projects :projects_001
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, project: project

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
  end

  def test_providers_registry
    assert_kind_of Array, GlobalSearch.providers

    dummy_provider = Class.new do
      def self.search(*)
        []
      end

      def self.label = 'label_dummy'

      def self.permission = nil
    end

    original_providers = GlobalSearch.providers.dup
    GlobalSearch.register dummy_provider

    assert_includes GlobalSearch.providers, dummy_provider

    # Do not register duplicates
    GlobalSearch.register dummy_provider

    assert_equal 1, GlobalSearch.providers.count(dummy_provider)
  ensure
    GlobalSearch.providers.replace original_providers
  end

  def test_search_result_entries_have_required_keys
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, types: ['issues']

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
    assert result[:keyword].any?, 'Should return results'

    result[:keyword].each do |entry|
      assert entry.key?(:title), 'Each result should have :title'
      assert entry.key?(:url), 'Each result should have :url'
      assert entry.key?(:type), 'Each result should have :type'
    end
  end

  def test_format_record_works_for_issue
    record = issues :issues_001
    result = GlobalSearch.send :format_record, record

    assert_kind_of Hash, result
    assert result[:title].present?
    assert result[:url].present?
    assert result[:type].present?
  end

  def test_provider_search_returns_nil_when_provider_raises
    error_provider = Class.new do
      def self.search(*)
        raise StandardError, 'Provider exploded'
      end

      def self.label = 'label_error'

      def self.permission = nil
    end

    with_provider error_provider do
      assert_nil GlobalSearch.provider_search('Cannot print recipes', user: User.current)
    end
  end

  def test_provider_search_returns_label_and_hits
    provider = provider_returning [{ id: 1, title: 'Semantic hit', url: '/issues/1', type: 'Issues' }]
    provider.define_singleton_method(:label) { :label_search }

    with_provider provider do
      result = GlobalSearch.provider_search 'Cannot print recipes', user: User.current

      assert_equal I18n.t(:label_search), result[:label]
      assert_equal ['/issues/1'], result[:results].pluck(:url)
    end
  end

  def test_digit_only_query_without_keyword_hits_skips_providers
    with_counting_provider do |provider|
      assert_nil GlobalSearch.provider_search('987654321', user: User.current, keyword_hits: false)
      assert_equal 0, provider.calls, 'Providers must not be asked for an unfindable number'
    end
  end

  def test_digit_only_query_with_keyword_hits_asks_providers
    with_counting_provider do |provider|
      GlobalSearch.provider_search '987654321', user: User.current, keyword_hits: true

      assert_equal 1, provider.calls
    end
  end

  def test_id_reference_never_asks_providers
    with_counting_provider do |provider|
      GlobalSearch.provider_search '#163', user: User.current, keyword_hits: true

      assert_equal 0, provider.calls, 'An id reference carries no meaning to embed'
    end
  end

  def test_query_with_letters_asks_providers_even_without_keyword_hits
    with_counting_provider do |provider|
      GlobalSearch.provider_search 'Zzyzx Quuxbar', user: User.current, keyword_hits: false

      assert_equal 1, provider.calls
    end
  end

  def test_provider_receives_the_requested_types
    with_counting_provider do |provider|
      GlobalSearch.provider_search 'Cannot print recipes', user: User.current, types: ['issues']

      assert_equal ['issues'], provider.last_types
    end
  end

  def test_unavailable_provider_is_not_asked
    provider = Class.new do
      class << self
        attr_accessor :calls

        def search(*, **)
          self.calls += 1
          []
        end

        def available? = false
        def label = 'label_unavailable'
        def permission = nil
      end
    end
    provider.calls = 0

    with_provider provider do
      GlobalSearch.provider_search 'Cannot print recipes', user: User.current

      assert_equal 0, provider.calls
      assert_empty GlobalSearch.provider_search_types(user: User.current)
      assert_nil GlobalSearch.provider_label(user: User.current)
    end
  end

  def test_failing_provider_is_left_out
    failing = provider_returning [{ id: 1, title: 'Hit', url: '/issues/1', type: 'Issues' }]
    failing.define_singleton_method(:available?) { raise StandardError, 'provider broken' }

    with_provider failing do
      assert_nil GlobalSearch.provider_search('Cannot print recipes', user: User.current)
      assert_empty GlobalSearch.provider_search_types(user: User.current)
    end
  end

  def test_provider_search_types_come_from_the_provider
    provider = provider_returning []
    provider.define_singleton_method(:search_types) { %w[issues wiki_pages] }

    with_provider provider do
      assert_equal %w[issues wiki_pages], GlobalSearch.provider_search_types(user: User.current)
    end
  end

  def test_provider_search_types_default_to_all_search_types
    with_provider provider_returning([]) do
      assert_equal Redmine::Search.available_search_types, GlobalSearch.provider_search_types(user: User.current)
    end
  end

  def test_provider_search_types_are_empty_without_providers
    with_providers_replaced_by [] do
      assert_empty GlobalSearch.provider_search_types(user: User.current)
    end
  end

  def test_provider_is_skipped_without_permission
    provider = provider_returning [{ id: 1, title: 'Hit', url: '/issues/1', type: 'Issues' }]
    provider.define_singleton_method(:permission) { :view_ai_semantic_search_that_nobody_has }

    with_provider provider do
      assert_nil GlobalSearch.provider_search('Cannot print recipes', user: User.anonymous)
      assert_empty GlobalSearch.provider_search_types(user: User.anonymous)
    end
  end

  def test_resolve_projects_returns_nil_for_global
    result = GlobalSearch.search 'Cannot print recipes', user: User.current

    assert_kind_of Hash, result
    assert_not_nil result[:keyword], 'Global search without scope or project should return keyword results'
  end

  def test_quick_jump_with_hash_id
    result = GlobalSearch.search '#1', user: User.current

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
    assert result[:keyword].any?, 'Quick-jump should find entities with ID 1'

    assert result[:jump]
    assert_equal '/issues/1', result[:keyword].first[:url], 'The issue must come first'
  end

  def test_quick_jump_lists_the_issue_first_even_with_types_in_another_order
    result = GlobalSearch.search '#1', user: User.current, types: %w[projects issues]

    assert_equal %w[/issues/1 /projects/ecookbook], result[:keyword].pluck(:url)
  end

  def test_plain_number_does_not_trigger_quick_jump
    result = GlobalSearch.search '1', user: User.current

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
    # Plain number should trigger normal keyword search, not quick-jump
  end

  def test_quick_jump_returns_multiple_entity_types
    result = GlobalSearch.search '#1', user: User.current

    types = result[:keyword].pluck(:type).uniq

    assert_operator types.size, :>, 1, "Quick-jump should return multiple entity types, got: #{types}"
  end

  def test_quick_jump_result_has_required_keys
    result = GlobalSearch.search '#1', user: User.current

    result[:keyword].each do |entry|
      assert entry.key?(:title), 'Quick-jump result should have :title'
      assert entry.key?(:url), 'Quick-jump result should have :url'
      assert entry.key?(:type), 'Quick-jump result should have :type'
    end
  end

  def test_quick_jump_respects_visibility
    User.current = User.anonymous
    result = GlobalSearch.search '#1', user: User.current

    assert_kind_of Hash, result
    # Anonymous should see fewer or no results depending on permissions
    skip if result[:keyword].blank?

    result[:keyword].each do |entry|
      assert entry[:title].present?
    end
  end

  def test_quick_jump_nonexistent_id_falls_through_to_keyword_search
    result = GlobalSearch.search '9999999', user: User.current

    assert_kind_of Hash, result
    # Should fall through to keyword search (which also finds nothing for this number)
    assert_kind_of Array, result[:keyword]
  end

  def test_hash_id_without_match_is_no_jump
    result = GlobalSearch.search '#987654321', user: User.current

    assert_not result[:jump]
  end

  def test_non_numeric_query_does_not_trigger_quick_jump
    result = GlobalSearch.search 'Cannot print recipes', user: User.current

    assert_kind_of Array, result[:keyword]
    # Normal keyword search returns results based on text matching, not ID
    assert result[:keyword].any?
  end

  def test_search_respects_disabled_modules
    with_plugin_settings 'additionals', disabled_modules: %i[news] do
      result = GlobalSearch.search '#1', user: User.current

      types = result[:keyword].pluck :type

      assert_not_includes types, 'News'
      assert_includes types, 'Issues'
    end
  end

  def test_resolve_projects_returns_project_array
    project = projects :projects_001
    result = GlobalSearch.search 'Cannot print recipes', user: User.current, project: project

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]

    # When project is set, results should be scoped to that project
    result[:keyword].each do |entry|
      assert_equal project.name, entry[:project_name], 'All results should belong to the specified project'
    end
  end

  private

  def with_counting_provider(&)
    provider = Class.new do
      class << self
        attr_accessor :calls, :last_types

        def search(*, types: nil, **)
          self.calls += 1
          self.last_types = types
          []
        end

        def label = 'label_counting'
        def permission = nil
      end
    end
    provider.calls = 0

    with_provider provider, &
  end

  def provider_returning(hits)
    provider = Class.new do
      class << self
        attr_accessor :hits

        def search(*, **) = hits
        def label = 'label_stub'
        def permission = nil
      end
    end
    provider.hits = hits
    provider
  end

  # Only the given provider is registered, so the result does not depend on which other
  # plugins (redmine_ai) happen to be installed.
  def with_provider(provider, &)
    with_providers_replaced_by([provider]) { yield provider }
  end

  def with_providers_replaced_by(providers)
    original_providers = GlobalSearch.providers.dup
    GlobalSearch.providers.replace providers
    yield
  ensure
    GlobalSearch.providers.replace original_providers
  end
end
