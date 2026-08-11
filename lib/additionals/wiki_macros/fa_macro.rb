# frozen_string_literal: true

module Additionals
  module WikiMacros
    # Hosts the {{tabler}} icon macro and its backward compatible {{fa}} alias.
    # Both render a Tabler sprite icon.
    module FaMacro
      # Options accepted by both macros
      OPTIONS = %i[class title text size color link repeat].freeze

      # Upper bound for repeat. Anyone allowed to edit a page could otherwise put
      # thousands of svg nodes on it, and a rating scale - what repeating an icon
      # is for - never needs more than this.
      MAX_REPEAT = 20

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

        # How often the icon is rendered. Anything but a positive number means once,
        # larger values are capped instead of rejected: the macro sits in a page and
        # should show something rather than an error.
        def repeat_count(value)
          count = value.to_i
          return 1 unless count.positive?

          [count, MAX_REPEAT].min
        end

        # Shared renderer for the {{tabler}} / {{fa}} macros. `view` is the macro
        # context (a view), which provides additionals_icon and the tag helpers.
        def render(view, args, options)
          css_classes = ['additionals-macro-icon']
          css_classes += options[:class].split if options[:class].present?

          icon_options = { css_class: css_classes.join(' ') }
          size = icon_size options[:size]
          icon_options[:size] = size if size

          icon = view.additionals_icon args[0], **icon_options
          # Text and wrapper apply to the group, not to every single icon.
          content = view.safe_join Array.new(repeat_count(options[:repeat]), icon)
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

      {{tabler(ICON [, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR, link=URL, repeat=COUNT])}}
      ICON   = tabler icon name (e.g. car); legacy values (fas_car) still work
      CLASS  = additional css classes
      TITLE  = mouseover title
      TEXT   = text to show next to the icon
      SIZE   = icon size in px (e.g. 24); legacy tokens (lg, 2x, ...) are mapped
      COLOR  = css color code
      LINK   = link the icon (and text) to this URL
      REPEAT = show the icon that many times, e.g. for a rating (at most 20)

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
      {{tabler(star-filled, repeat=3)}}
      ...show three filled stars
      {{tabler(star-filled, repeat=3, color=#f59f00, text=3 of 5)}}
      ...show three filled stars in yellow, followed by the text
        DESCRIPTION

        macro :tabler do |_obj, args|
          args, options = extract_macro_options args, *Additionals::WikiMacros::FaMacro::OPTIONS
          raise 'The correct usage is {{tabler(<ICON>, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR)}}' if args.empty?

          Additionals::WikiMacros::FaMacro.render self, args, options
        end

        desc <<-DESCRIPTION
    Backward compatible alias for {{tabler}}.

    Syntax:

      {{fa(ICON [, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR, link=URL, repeat=COUNT])}}

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
