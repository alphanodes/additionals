# frozen_string_literal: true

require File.expand_path '../../test_helper', __FILE__

class AdditionalsIconTest < Additionals::TestCase
  def setup
    AdditionalsIcon.reset!
  end

  def test_resolve_translates_legacy_solid_value
    assert_equal 'car', AdditionalsIcon.resolve('fas_car')
  end

  def test_resolve_translates_legacy_brand_value
    assert_equal 'brand-drupal', AdditionalsIcon.resolve('fab_drupal')
  end

  def test_resolve_passes_through_tabler_name
    assert_equal 'car', AdditionalsIcon.resolve('car')
  end

  def test_resolve_returns_fallback_for_blank
    assert_equal AdditionalsIcon::FALLBACK, AdditionalsIcon.resolve('')
    assert_equal AdditionalsIcon::FALLBACK, AdditionalsIcon.resolve(nil)
  end

  def test_resolve_returns_fallback_for_unmapped_legacy
    assert_equal 'point', AdditionalsIcon.resolve('fas_dragon')
  end

  def test_resolve_returns_fallback_for_unknown_name
    assert_equal 'point', AdditionalsIcon.resolve('no-such-icon-xyz')
  end

  def test_resolve_maps_semantic_gaps
    assert_equal 'tool', AdditionalsIcon.resolve('fas_wrench')
    assert_equal 'mail', AdditionalsIcon.resolve('fas_envelope')
    assert_equal 'user-shield', AdditionalsIcon.resolve('fas_user-secret')
  end

  def test_resolve_maps_bare_fontawesome_name_via_legacy_map
    # bare FontAwesome names (no fas_/far_/fab_ prefix), as used by the
    # {{fa}}/{{tabler}} wiki macros, resolve through the legacy map
    assert_equal 'file', AdditionalsIcon.resolve('file-alt')
    assert_equal 'tool', AdditionalsIcon.resolve('wrench')
    assert_equal 'list-numbers', AdditionalsIcon.resolve('list-ol')
    assert_equal 'gender-female', AdditionalsIcon.resolve('female')
  end

  def test_resolve_prefers_tabler_name_over_legacy_map
    # a value that is itself a valid tabler name is used as-is, never remapped
    assert_equal 'file', AdditionalsIcon.resolve('file')
    assert_equal 'flag', AdditionalsIcon.resolve('flag')
  end

  def test_legacy_detection
    assert AdditionalsIcon.legacy?('fas_car')
    assert AdditionalsIcon.legacy?('fab_drupal')
    assert_not AdditionalsIcon.legacy?('car')
    assert_not AdditionalsIcon.legacy?('brand-gitlab')
  end

  def test_sprite_resolution
    assert_equal 'icons_custom', AdditionalsIcon.sprite('matomo')
    assert_equal 'icons_custom', AdditionalsIcon.sprite('redmine')
    assert_equal 'icons', AdditionalsIcon.sprite('car')
    assert_equal 'icons', AdditionalsIcon.sprite('brand-gitlab')
  end

  def test_known
    assert AdditionalsIcon.known?('car')
    assert AdditionalsIcon.known?('brand-gitlab')
    assert AdditionalsIcon.known?('matomo')
    assert_not AdditionalsIcon.known?('no-such-icon-xyz')
    assert_not AdditionalsIcon.known?('fas_car')
  end

  def test_custom_brand_marks_are_known_and_selectable
    %w[shelly victron zabbix].each do |name|
      assert AdditionalsIcon.known?(name), "#{name} should be a known custom brand mark"
      assert_equal 'icons_custom', AdditionalsIcon.sprite(name)
      assert_includes AdditionalsIcon.selectable, name
    end
  end

  def test_selectable_is_sorted_and_present
    list = AdditionalsIcon.selectable

    assert_includes list, 'car'
    assert_includes list, 'matomo'
    assert_not_includes list, 'fas_car'
    assert_equal list.sort, list
  end

  def test_inline_svg_returns_standalone_svg_with_color_and_paths
    svg = AdditionalsIcon.inline_svg 'car', color: '#ff0000', size: 32

    assert_match %r{\A<svg xmlns="http://www.w3.org/2000/svg"}, svg
    assert_match(/width="32" height="32"/, svg)
    assert_match(/stroke="#ff0000"/, svg)
    assert_match(/<path /, svg)
    assert_match %r{</svg>\z}, svg
  end

  def test_inline_svg_translates_legacy_value
    svg = AdditionalsIcon.inline_svg 'fas_car'

    assert_match(/<path /, svg)
  end

  def test_inline_svg_falls_back_for_unknown_value
    svg = AdditionalsIcon.inline_svg 'no-such-icon-xyz'

    # unknown resolves to the point fallback, which still yields a drawable svg
    assert_match(/<svg /, svg)
    assert_match(/<path /, svg)
  end
end
