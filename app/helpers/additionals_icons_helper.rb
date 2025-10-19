# frozen_string_literal: true

module AdditionalsIconsHelper
  include IconsHelper

  def h2_page_icon(icon_name, **)
    svg_icon_tag(icon_name, size: 24, css_class: 'icon-padding', **)
  end

  def svg_icon_tag(icon_name,
                   label: nil,
                   size: nil,
                   css_class: nil,
                   label_type: :span,
                   rtl: nil,
                   style: nil,
                   icon_only: false,
                   plugin: 'additionals',
                   sprite: nil,
                   wrapper: nil,
                   wrapper_content: nil,
                   wrapper_class: 'icon',
                   wrapper_title: nil,
                   wrapper_css: nil)
    sprite ||= IconsHelper::DEFAULT_SPRITE
    sprite = plugin.present? ? "plugin_assets/#{plugin}/#{sprite}.svg" : "#{sprite}.svg"

    icon_options = { sprite: }
    icon_options[:size] = size if size
    icon_options[:css_class] = css_class if css_class

    icon_options[:rtl] = rtl if rtl
    icon_options[:style] = style if style

    content = svg_sprite_icon icon_name, **icon_options
    if label
      label_classes = ['icon-label']
      label_classes << 'hidden' if icon_only

      content << content_tag(label_type,
                             label.is_a?(Symbol) ? l(label) : label,
                             class: label_classes.join(' '))
    end

    return content unless wrapper

    svg_icon_wrapper content, icon_name:,
                              wrapper:,
                              wrapper_content:,
                              wrapper_class:,
                              wrapper_title:,
                              wrapper_css:
  end

  private

  def svg_icon_wrapper(content, icon_name:, wrapper:, wrapper_content:, wrapper_class:, wrapper_title:, wrapper_css:)
    wrapper_title = l wrapper_title if wrapper_title.is_a? Symbol

    content << wrapper_content if wrapper_content
    wrapper_classes = "#{wrapper_class} icon-#{icon_name}"
    wrapper_classes += " #{wrapper_css}" if wrapper_css
    content_tag wrapper, content, class: wrapper_classes, title: wrapper_title
  end
end
