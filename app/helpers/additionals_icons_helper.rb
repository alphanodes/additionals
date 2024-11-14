# frozen_string_literal: true

module AdditionalsIconsHelper
  DEFAULT_ICON_SIZE = '18'
  DEFAULT_SPRITE = 'icons'

  def h2_page_icon(icon_name, **options)
    svg_icon_tag(icon_name, size: 24, css_class: 'icon-padding', **options)
  end

  def svg_icon_tag(icon_name,
                   label: nil,
                   size: DEFAULT_ICON_SIZE,
                   css_class: nil,
                   label_type: :span,
                   title: nil,
                   icon_only: false,
                   plugin: 'additionals',
                   sprite: DEFAULT_SPRITE,
                   wrapper: nil,
                   wrapper_content: nil,
                   wrapper_class: 'icon',
                   wrapper_css: nil)

    sprite = plugin.present? ? "plugin_assets/#{plugin}/#{sprite}.svg" : "#{sprite}.svg"
    content = additionals_svg_sprite_icon(icon_name, size:, sprite:, title:, css_class:)

    if label
      label_classes = ['icon-label']
      label_classes << 'hidden' if icon_only

      content << content_tag(label_type,
                             label.is_a?(Symbol) ? l(label) : label,
                             class: label_classes.join(' '))
    end

    return content unless wrapper

    content << wrapper_content if wrapper_content
    wrapper_classes = "#{wrapper_class} icon-#{icon_name}"
    wrapper_classes += " #{wrapper_css}" if wrapper_css
    content_tag wrapper, content, class: wrapper_classes
  end

  private

  # @NOTE: same as svg_sprite_icon, but title support
  def additionals_svg_sprite_icon(icon_name, size: DEFAULT_ICON_SIZE, sprite: DEFAULT_SPRITE, css_class: nil, title: nil)
    title = l title if title.is_a? Symbol
    css_classes = "s#{size} icon-svg"
    css_classes += " #{css_class}" if css_class

    content_tag(
      :svg,
      content_tag(:use,
                  '',
                  { 'href' => "#{asset_path sprite}#icon--#{icon_name}" }),
      class: css_classes,
      title: title.presence,
      aria: { hidden: true }
    )
  end
end
