# frozen_string_literal: true

require_relative '../test_helper'

class AdditionalsInfoTest < Additionals::TestCase
  def test_system_infos
    infos = AdditionalsInfo.new.system_infos

    assert infos.is_a? Hash
    assert infos.count >= 3
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
