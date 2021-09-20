# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsPluginTest < Additionals::TestCase
  def test_known_plugin
    assert_not AdditionalsPlugin.active_sudo?
  end

  def test_unknown_plugin
    assert_not AdditionalsPlugin.active_unknown?
  end

  def test_invalid_method_name_should_raise_error
    assert_raises NoMethodError do
      AdditionalsPlugin.run_unknown?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run_unknown
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.unknown?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run_?
    end

    assert_raises NoMethodError do
      assert_not AdditionalsPlugin.run
    end
  end
end
