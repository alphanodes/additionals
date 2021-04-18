# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Show Font Awesome icon.

  Syntax:

     {{fa(ICON [, class=CLASS, title=TITLE, text=TEXT size=SIZE, color=COLOR)}}
     ICON of fontawesome icon, eg. fa-adjust
     CLASS = additional css classes
     TITLE = mouseover title
     TEXT = Text to show
     LINK = Link icon and text (if specified) to this URL
     COLOR = css color code

  Examples:

     {{fa(adjust)}}
     ...show fontawesome icon "fas fa-adjust"
     {{fa(adjust, class=fa-inverse)}}
      ...show fontawesome icon "fas fa-stack" and inverse
     {{fa(adjust, size=4x)}}
       ...show fontawesome icon "fas fa-adjust" with size 4x
     {{fa(fas_adjust, title=Show icon)}}
     ...show fontawesome icon "fas fa-adjust" with title "Show icon"
     {{fa(fab_angellist)}}
     ...Show fontawesome icon "fab fa-angellist"
     {{fa(adjust, link=https=//www.redmine.org))}}
     ...Show fontawesome icon "fas fa-adjust" and link it to https://www.redmine.org
     {{fa(adjust, link=https=//www.redmine.de, name=Go to Redmine.org))}}
     ...Show fontawesome icon "fas fa-adjust" with name "Go to Redmine.org" and link it to https://www.redmine.org
      DESCRIPTION

      macro :fa do |_obj, args|
        args, options = extract_macro_options args, :class, :title, :text, :size, :color, :link
        raise 'The correct usage is {{fa(<ICON>, class=CLASS, title=TITLE, text=TEXT, size=SIZE, color=COLOR)}}' if args.empty?

        values = args[0].split '_'

        classes = []
        if values.count == 2
          classes << values[0]
          classes << "fa-#{values[1]}"
        else
          classes << 'fas'
          classes << "fa-#{values[0]}"
        end

        classes += options[:class].split if options[:class].present?
        classes << "fa-#{options[:size]}" if options[:size].present?

        content_options = { class: classes.uniq.join(' ') }
        content_options[:title] = options[:title] if options[:title].present?
        content_options[:style] = "color: #{options[:color]}" if options[:color].present?

        text = options[:text].present? ? " #{options[:text]}" : ''

        if options[:link].present?
          tag.a href: options[:link] do
            tag.i text, content_options
          end
        else
          tag.i text, **content_options
        end
      end
    end
  end
end
