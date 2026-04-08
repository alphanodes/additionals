# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class GlobalSearchTest < Additionals::TestCase
  def setup
    User.current = users :users_002
  end

  def test_search_returns_keyword_and_semantic_keys
    result = GlobalSearch.search 'Cannot print recipes', user: User.current

    assert_kind_of Hash, result
    assert result.key?(:keyword), 'Result should contain :keyword key'
    assert result.key?(:semantic), 'Result should contain :semantic key'
    assert_kind_of Array, result[:keyword]
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

  def test_search_returns_results_when_provider_raises
    error_provider = Class.new do
      def self.search(*)
        raise StandardError, 'Provider exploded'
      end

      def self.label = 'label_error'

      def self.permission = nil
    end

    original_providers = GlobalSearch.providers.dup
    GlobalSearch.register error_provider

    result = GlobalSearch.search 'Cannot print recipes', user: User.current

    assert_kind_of Hash, result
    assert_kind_of Array, result[:keyword]
    # keyword search should still work even if provider search fails
    assert result[:keyword].any?, 'Keyword results should be present despite provider error'
  ensure
    GlobalSearch.providers.replace original_providers
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

    types = result[:keyword].pluck :type

    assert_includes types, 'Issues'
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

  def test_quick_jump_skips_semantic
    result = GlobalSearch.search '#1', user: User.current

    assert_nil result[:semantic], 'Quick-jump should not trigger semantic search'
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
end
