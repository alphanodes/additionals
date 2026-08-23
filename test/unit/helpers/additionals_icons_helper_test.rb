# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

# Form object with an icon attribute that is not named :icon, mirroring how
# plugins dodge a column collision (redmine_reporting stores `reporting_icon`).
# A stub rather than the real model, because additionals is tested on its own
# and must not depend on a plugin that provides such a column.
class IconFieldStub
  include ActiveModel::Model

  attr_accessor :reporting_icon
end

class AdditionalsIconsHelperTest < Additionals::HelperTest
  include AdditionalsIconsHelper

  def setup
    AdditionalsIcon.reset!
  end

  def test_additionals_icon_renders_legacy_value_from_main_sprite
    html = additionals_icon 'fas_car'

    assert_match(/<svg\b/, html)
    assert_match %r{#icon--car}, html
    assert_no_match(/icons_custom/, html)
  end

  def test_additionals_icon_renders_tabler_name
    html = additionals_icon 'brand-gitlab'

    assert_match %r{#icon--brand-gitlab}, html
  end

  def test_additionals_icon_renders_custom_brand_from_custom_sprite
    html = additionals_icon 'matomo'

    assert_match(/icons_custom.*#icon--matomo/m, html)
  end

  def test_additionals_icon_renders_nothing_for_blank
    assert_equal '', additionals_icon('')
    assert_equal '', additionals_icon(nil)
  end

  def test_additionals_icon_translates_semantic_gap
    html = additionals_icon 'fas_wrench'

    assert_match %r{#icon--tool}, html
  end

  def test_additionals_icon_renders_bare_fontawesome_name
    # bare FontAwesome names from the {{fa}}/{{tabler}} wiki macros
    assert_match %r{#icon--file}, additionals_icon('file-alt')
    assert_match %r{#icon--tool}, additionals_icon('wrench')
    assert_match %r{#icon--list-numbers}, additionals_icon('list-ol')
  end

  def test_additionals_icon_applies_size_class
    html = additionals_icon 'list-ol', size: 40, css_class: 'additionals-macro-icon'

    assert_match %r{#icon--list-numbers}, html
    assert_match(/class="s40 icon-svg additionals-macro-icon"/, html)
  end

  def test_icon_sprites_carry_the_digested_asset_paths
    sprites = additionals_icon_sprites

    assert_match %r{/icons-\w+\.svg\z}, sprites[:core]
    assert_match %r{/additionals/icons-\w+\.svg\z}, sprites[:additionals]
    assert_match %r{/additionals/icons_custom-\w+\.svg\z}, sprites[:additionals_custom]
  end

  def test_icon_select_options_carry_main_sprite_href
    car = send(:additionals_icon_select_options, nil).find { |option| option[1] == 'car' }

    assert_not_nil car
    assert_match %r{/additionals/icons-\w+\.svg#icon--car\z}, car[2]['data-href']
    assert_no_match(/icons_custom/, car[2]['data-href'])
  end

  def test_icon_select_options_carry_custom_sprite_href
    matomo = send(:additionals_icon_select_options, nil).find { |option| option[1] == 'matomo' }

    assert_not_nil matomo
    assert_match(/icons_custom.*#icon--matomo/, matomo[2]['data-href'])
  end

  def test_icon_select_options_include_known_selected_outside_subset
    values = send(:additionals_icon_select_options, 'circle-check').pluck(1)

    assert_includes values, 'circle-check'
  end

  def test_additionals_icon_renders_post_text_after_icon
    html = additionals_icon 'car', post_text: 'My Car'

    assert_match %r{#icon--car.*My Car}m, html
  end

  def test_additionals_icon_renders_pre_text_before_icon
    html = additionals_icon 'car', pre_text: 'Label'

    assert_match %r{Label.*#icon--car}m, html
  end

  def test_additionals_icon_wraps_title_in_span
    html = additionals_icon 'car', title: 'Tooltip'

    assert_match %r{<span title="Tooltip">.*#icon--car.*</span>}m, html
  end

  def test_additionals_icon_accepts_class_alias_for_css_class
    html = additionals_icon 'car', class: 'my-icon'

    assert_match(/my-icon/, html)
  end

  def test_additionals_icon_select_tag_renders_select_with_options
    html = additionals_icon_select_tag 'menu_symbol', 'car', class: 'select2-icon-field menu'

    assert_match %r{<select[^>]*name="menu_symbol"}, html
    assert_match(/select2-icon-field menu/, html)
    assert_match %r{<option[^>]*selected="selected"[^>]*value="car"}, html
  end

  def test_additionals_icon_select_tag_resolves_legacy_selected
    html = additionals_icon_select_tag 'menu_symbol', 'fas_car'

    assert_match %r{<option[^>]*selected="selected"[^>]*value="car"}, html
  end

  def test_additionals_icon_loader_renders_select2_init
    js = additionals_icon_loader field_class: 'select2-menu-icon-field'

    assert_match(/select2-menu-icon-field/, js)
    assert_match(/formatIconOption/, js)
  end

  def test_additionals_icon_select_labels_a_renamed_icon_field
    html = with_settings default_language: 'en' do
      additionals_icon_select icon_form_builder, nil, icon_field: :reporting_icon, loader: false
    end

    # without the shared label the form builder would humanize the attribute name
    assert_match %r{<label[^>]*for="project_reporting_icon"[^>]*>Icon</label>}, html
    assert_no_match(/Reporting icon/, html)
  end

  def test_additionals_icon_select_label_can_be_overwritten
    html = with_settings default_language: 'en' do
      additionals_icon_select icon_form_builder, nil, icon_field: :reporting_icon, label: :field_name, loader: false
    end

    assert_match %r{<label[^>]*>Name</label>}, html
  end

  private

  def icon_form_builder
    Redmine::Views::LabelledFormBuilder.new :project, IconFieldStub.new, self, {}
  end
end
