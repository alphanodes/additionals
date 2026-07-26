# frozen_string_literal: true

module Additionals
  module WikiMacros
    # Hosts the {{tabler}} icon macro and its backward compatible {{fa}} alias.
    # Both render a Tabler sprite icon.
    module FaMacro
      # Options accepted by both macros
      OPTIONS = %i[class title text size color link].freeze

      # Map legacy size tokens to a tabler pixel size that has a matching .s<n>
      # css class. Plain numbers pass through unchanged.
      LEGACY_SIZES = { 'xs' => 12, 'sm' => 14, 'lg' => 22,
                       '2x' => 40, '3x' => 50, '4x' => 50, '5x' => 50 }.freeze

      class << self
        # Translate a size option into a numeric tabler icon size (or nil)
        def icon_size(value)
          return if value.blank?

          value = value.to_s
          LEGACY_SIZES[value] || (value.match?(/\A\d+\z/) ? value.to_i : nil)
        end

        # Shared renderer for the {{tabler}} / {{fa}} macros. `view` is the macro
        # context (a view), which provides additionals_icon and the tag helpers.
        def render(view, args, options)
          css_classes = ['additionals-macro-icon']
          css_classes += options[:class].split if options[:class].present?

          icon_options = { css_class: css_classes.join(' ') }
          size = icon_size options[:size]
          icon_options[:size] = size if size

          content = view.additionals_icon args[0], **icon_options
          content = view.safe_join [content, options[:text]], ' ' if options[:text].present?

          wrapper = {}
          wrapper[:title] = options[:title] if options[:title].present?
          wrapper[:style] = "color: #{options[:color]}" if options[:color].present?

          if options[:link].present?
            view.link_to content, options[:link], **wrapper
          elsif wrapper.any?
            view.tag.span content, **wrapper
          else
            content
          end
        end
      end

      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Show an icon from the Tabler icon set.

    Syntax:

      {{tabler(ICON [, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR, link=URL])}}
      ICON  = tabler icon name (e.g. car); legacy values (fas_car) still work
      CLASS = additional css classes
      TITLE = mouseover title
      TEXT  = text to show next to the icon
      SIZE  = icon size in px (e.g. 24); legacy tokens (lg, 2x, ...) are mapped
      COLOR = css color code
      LINK  = link the icon (and text) to this URL

    Examples:

      {{tabler(car)}}
      ...show the tabler "car" icon
      {{tabler(car, title=Show icon)}}
      ...show the "car" icon with title "Show icon"
      {{tabler(car, size=24)}}
      ...show the "car" icon at 24px
      {{tabler(car, color=#ff0000)}}
      ...show the "car" icon in red
      {{tabler(car, link=https://www.redmine.org, text=Go to Redmine.org)}}
      ...show the "car" icon with text, linked to redmine.org
        DESCRIPTION

        macro :tabler do |_obj, args|
          args, options = extract_macro_options args, *Additionals::WikiMacros::FaMacro::OPTIONS
          raise 'The correct usage is {{tabler(<ICON>, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR)}}' if args.empty?

          Additionals::WikiMacros::FaMacro.render self, args, options
        end

        desc <<-DESCRIPTION
    Backward compatible alias for {{tabler}}.

    Syntax:

      {{fa(ICON [, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR, link=URL])}}

    Legacy values (e.g. fas_car) are translated to the matching
    tabler icon. Prefer {{tabler}} for new content.
        DESCRIPTION

        macro :fa do |_obj, args|
          args, options = extract_macro_options args, *Additionals::WikiMacros::FaMacro::OPTIONS
          raise 'The correct usage is {{fa(<ICON>, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR)}}' if args.empty?

          Additionals::WikiMacros::FaMacro.render self, args, options
        end
      end
    end
  end
end
