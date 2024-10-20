# frozen_string_literal: true

module AdditionalsIconsHelper
  DEFAULT_ICON_SIZE = '18'

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
                   wrapper: nil,
                   wrapper_content: nil,
                   wrapper_class: 'a-icon',
                   wrapper_css: nil)

    svg_code = additionals_svg_sprite_icon(icon_name, size:, title:, css_class:)

    content = svg_code.dup

    if label
      label_classes = ['a-icon-label']
      label_classes << 'hidden' if icon_only

      content << content_tag(label_type,
                             label.is_a?(Symbol) ? l(label) : label,
                             class: label_classes.join(' '))
    end

    return content unless wrapper

    content << wrapper_content if wrapper_content
    wrapper_classes = "#{wrapper_class} a-icon-#{icon_name}"
    wrapper_classes += " #{wrapper_css}" if wrapper_css
    content_tag wrapper, content, class: wrapper_classes
  end

  def additionals_asset_path(file)
    plugin_id = 'additionals'

    if Additionals.redmine6?
      asset_path "plugin_assets/#{plugin_id}/#{file}"
    else
      "#{additionals_image_path plugin_id}/#{file}"
    end
  end

  def additionals_image_path(plugin_id)
    return asset_path if Additionals.redmine6?
    return @additionals_image_path if defined? @additionals_image_path

    relative_url = Redmine::Utils.relative_url_root
    @additionals_image_path = "#{relative_url}/plugin_assets/#{plugin_id}/images"
  end

  private

  def additionals_svg_sprite_icon(icon_name, size: DEFAULT_ICON_SIZE, sprite: 'icons', css_class: nil, title: nil)
    sprite_path = "#{sprite}.svg"
    title = l title if title.is_a? Symbol
    css_classes = "a-s#{size} a-svg-icon"
    css_classes += " #{css_class}" if css_class

    content_tag(
      :svg,
      content_tag(:use,
                  '',
                  { 'href' => additionals_asset_path("#{sprite_path}#icon--#{icon_name}") }),
      class: css_classes,
      title: title.presence,
      aria: { hidden: true }
    )
  end

  def svg_icon_for_mime_type(mime)
    if %w[text-plain text-x-c text-x-csharp text-x-java text-x-php
          text-x-ruby text-xml text-css text-html text-css text-html
          image-gif image-jpeg image-png image-tiff
          application-pdf application-zip application-gzip application-javascript].include?(mime)
      mime
    else
      'file'
    end
  end
end
