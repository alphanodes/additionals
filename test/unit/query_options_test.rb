# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

# Options plugins add to saved queries, described like settings
class QueryOptionsTest < Additionals::TestCase
  # A query class with an option of its own, as a plugin adds one
  class OptionQuery < ProjectQuery
    def query_options_definitions
      super.merge mode: { type: :enum, label: :field_status }
    end

    def query_option_values
      super.merge mode: options[:mode]
    end

    def query_option_params(values)
      super.merge mode: values.to_h.symbolize_keys[:mode]
    end

    def query_option_mode_values(_schema)
      %w[compact full]
    end
  end

  def setup
    prepare_tests
    User.current = users :users_001
  end

  def test_options_are_checked_with_the_rules_of_the_query
    assert_includes OptionQuery.new.query_options_schema(mode: 'huge').errors, :mode
  end

  def test_stored_options_complete_given_ones
    query = OptionQuery.new
    query.options[:mode] = 'full'

    assert_equal 'full', query.query_options_schema[:mode]
  end

  def test_option_params_are_built_by_the_query
    assert_equal 'compact', OptionQuery.new.query_option_params(mode: 'compact')[:mode]
  end
end
