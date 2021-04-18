# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsInfoTest < Additionals::TestCase
  def test_system_info
    text = AdditionalsInfo.system_info
    assert_not_equal '', text
    assert_not_equal 'unknown', text
  end

  def test_windows_platform
    assert_not AdditionalsInfo.windows_platform?
  end
end
