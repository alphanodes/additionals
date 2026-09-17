# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class AdditionalsGlobalSearchHelperTest < Additionals::HelperTest
  include AdditionalsGlobalSearchHelper
  include AdditionalsIconsHelper
  include IconsHelper
  include Redmine::I18n

  def setup
    super
    User.current = users :users_002
    @original_providers = GlobalSearch.providers.dup
  end

  def teardown
    GlobalSearch.providers.replace @original_providers
    super
  end

  def test_global_search_data_lists_the_provider_types
    GlobalSearch.providers.replace [provider(search_types: %w[issues])]

    data = global_search_data

    assert_equal '/global_search/semantic', data[:'semantic-url']
    assert_equal '["issues"]', data[:'semantic-types']
    assert_equal I18n.t(:label_search), data[:'semantic-label']
  end

  private

  def provider(search_types:)
    Class.new do
      define_singleton_method(:search) { |*, **| [] }
      define_singleton_method(:search_types) { search_types }
      define_singleton_method(:label) { :label_search }
      define_singleton_method(:permission) { nil }
    end
  end
end
