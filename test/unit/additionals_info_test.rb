# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsInfoTest < Additionals::TestCase
  def test_system_infos
    infos = AdditionalsInfo.new.system_infos

    assert_kind_of Hash, infos
    assert_operator infos.count, :>=, 3
  end

  def test_system_info
    text = AdditionalsInfo.new.system_info

    assert_not_empty text
    assert_not_equal 'unknown', text
  end

  def test_system_uptime
    info = AdditionalsInfo.new.system_uptime

    assert info.present?
  end
end
