# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsConfTest < Additionals::TestCase
  def test_configuration_false_overrides_default_true
    Redmine::Configuration.with 'additionals_test_flag' => false do
      assert_not AdditionalsConf.with_system_default('ADDITIONALS_TEST_FLAG', type: 'bool', default: true)
    end
  end

  def test_configuration_true_overrides_default_false
    Redmine::Configuration.with 'additionals_test_flag' => true do
      assert AdditionalsConf.with_system_default('ADDITIONALS_TEST_FLAG', type: 'bool', default: false)
    end
  end

  def test_blank_configuration_falls_back_to_default
    Redmine::Configuration.with 'additionals_test_flag' => '' do
      assert AdditionalsConf.with_system_default('ADDITIONALS_TEST_FLAG', type: 'bool', default: true)
    end
  end

  # An empty list in configuration.yml, e.g. from a template with an empty
  # variable, would switch off what the default turns on
  def test_empty_list_in_configuration_falls_back_to_default
    Redmine::Configuration.with 'additionals_test_list' => [] do
      assert_equal %w[database], AdditionalsConf.with_system_default('ADDITIONALS_TEST_LIST', type: 'array', default: %w[database])
    end
  end

  def test_missing_configuration_falls_back_to_default
    assert_equal 7, AdditionalsConf.with_system_default('ADDITIONALS_TEST_MISSING', default: 7)
  end
end
