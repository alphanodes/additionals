# frozen_string_literal: true

module AdditionalsIconsHelper
  include IconsHelper

  def h2_page_icon(icon_name, **)
    svg_icon_tag(icon_name, size: 24, css_class: 'icon-padding', **)
  end

  # Render an icon from a stored icon value: a tabler sprite name, or a legacy
  # value (e.g. "fas_car") that is translated to its tabler equivalent.
  #
  # Options: :pre_text/:post_text (text before/after the icon), :title (tooltip
  # on a wrapper span), :class (alias for :css_class). Remaining options pass
  # through to svg_icon_tag. A blank value renders nothing.
  def additionals_icon(value, **options)
    return ''.html_safe if value.blank?

    name = AdditionalsIcon.resolve value
    pre_text = options.delete :pre_text
    post_text = options.delete :post_text
    title = options.delete :title
    options[:css_class] = options.delete :class if options.key?(:class) && !options.key?(:css_class)

    icon = svg_icon_tag name, sprite: AdditionalsIcon.sprite(name), **options
    return icon if pre_text.blank? && post_text.blank? && title.blank?

    parts = []
    parts << pre_text if pre_text.present?
    parts << icon
    parts << post_text if post_text.present?
    content = safe_join parts, ' '
    title.present? ? tag.span(content, title:) : content
  end

  # Tabler icon picker: a select2 dropdown with SVG previews, populated client
  # side from the curated selectable list (no AJAX).
  def additionals_icon_select(form, selected, **options)
    icon_field = options.delete(:icon_field) || :icon
    name = options.delete(:name) || icon_field
    required = options.delete :required
    include_blank = options.delete :include_blank
    include_blank = !required if include_blank.nil?
    field_class = options.delete(:class) || 'select2-icon-field'
    # loader: false skips the per-field select2 init (a shared
    # additionals_icon_loader initializes all matching fields instead)
    loader = options.delete :loader
    loader = true if loader.nil?
    selected = AdditionalsIcon.resolve selected if selected.present?

    if include_blank
      options[:placeholder] ||= l :label_disabled
      options[:allow_clear] = true unless options.key? :allow_clear
    end
    options[:width] ||= '250px'

    select = form.select name,
                         options_for_select(additionals_icon_select_options(selected), selected),
                         { include_blank: },
                         class: field_class
    return select unless loader

    safe_join [select,
               render(layout: false,
                      partial: 'additionals/select2_icon_call',
                      formats: [:js],
                      locals: { field_class:, options: })]
  end

  # Raw select_tag variant of the icon picker, for repeated rows that are not
  # backed by a form builder (e.g. custom menu item symbols). Renders only the
  # <select>; initialize the select2 behaviour once via additionals_icon_loader.
  def additionals_icon_select_tag(name, selected, **options)
    include_blank = options.delete :include_blank
    include_blank = true if include_blank.nil?
    field_class = options.delete(:class) || 'select2-icon-field'
    selected = AdditionalsIcon.resolve selected if selected.present?

    select_options = { include_blank:, class: field_class }
    select_options[:id] = options[:id] if options.key? :id

    select_tag name,
               options_for_select(additionals_icon_select_options(selected), selected),
               **select_options
  end

  # One-shot select2 initializer for all icon selects matching field_class.
  # Use once at the bottom of a form that renders additionals_icon_select_tag rows.
  def additionals_icon_loader(field_class: 'select2-icon-field', **options)
    options[:placeholder] ||= l :label_disabled
    options[:allow_clear] = true unless options.key? :allow_clear
    options[:width] ||= '250px'

    render layout: false,
           partial: 'additionals/select2_icon_call',
           formats: [:js],
           locals: { field_class:, options: }
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

  # Build [name, value, {data-href}] tuples so select2 can render an SVG
  # preview per option (the sprite href is resolved server side).
  def additionals_icon_select_options(selected)
    main_sprite = asset_path 'plugin_assets/additionals/icons.svg'
    custom_sprite = asset_path 'plugin_assets/additionals/icons_custom.svg'
    selectable = AdditionalsIcon.selectable
    selectable |= [selected] if selected.present? && AdditionalsIcon.known?(selected)

    selectable.map do |name|
      base = AdditionalsIcon.sprite(name) == AdditionalsIcon::CUSTOM_SPRITE ? custom_sprite : main_sprite
      [name, name, { 'data-href' => "#{base}#icon--#{name}" }]
    end
  end

  def svg_icon_wrapper(content, icon_name:, wrapper:, wrapper_content:, wrapper_class:, wrapper_title:, wrapper_css:)
    wrapper_title = l wrapper_title if wrapper_title.is_a? Symbol

    content << wrapper_content if wrapper_content
    wrapper_classes = "#{wrapper_class} icon-#{icon_name}"
    wrapper_classes += " #{wrapper_css}" if wrapper_css
    content_tag wrapper, content, class: wrapper_classes, title: wrapper_title
  end
end
