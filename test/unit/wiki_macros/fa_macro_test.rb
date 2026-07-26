# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class FaMacroTest < Additionals::TestCase
  def test_icon_size_maps_legacy_fontawesome_tokens
    assert_equal 12, Additionals::WikiMacros::FaMacro.icon_size('xs')
    assert_equal 14, Additionals::WikiMacros::FaMacro.icon_size('sm')
    assert_equal 22, Additionals::WikiMacros::FaMacro.icon_size('lg')
    assert_equal 40, Additionals::WikiMacros::FaMacro.icon_size('2x')
    assert_equal 50, Additionals::WikiMacros::FaMacro.icon_size('4x')
  end

  def test_icon_size_passes_plain_numbers_through
    assert_equal 24, Additionals::WikiMacros::FaMacro.icon_size('24')
    assert_equal 18, Additionals::WikiMacros::FaMacro.icon_size(18)
  end

  def test_icon_size_returns_nil_for_blank_or_unknown
    assert_nil Additionals::WikiMacros::FaMacro.icon_size(nil)
    assert_nil Additionals::WikiMacros::FaMacro.icon_size('')
    assert_nil Additionals::WikiMacros::FaMacro.icon_size('huge')
  end
end
