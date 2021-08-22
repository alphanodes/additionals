# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Google docs macro to include Google documents.

  Syntax:

    {{google_docs(<link> [, width=100%, height=485, edit_link=LINK)}}

  Examples:

    {{google_docs(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml)}
    {{google_docs(https://docs.google.com/spreadsheets/d/e/2PACX-1vQL__Vgu0Y0f-P__GJ9kpUmQ0S-HG56ni_b-x4WpWxzGIGXh3X6A587SeqvJDpH42rDmWVZoUN07VGE/pubhtml, width=514, height=422)}
      DESCRIPTION

      macro :google_docs do |_obj, args|
        args, options = extract_macro_options args, :width, :height, :edit_link

        width = options[:width].presence || '100%'
        height = options[:height].presence || 485

        raise 'The correct usage is {{google_docs(<link>[, width=x, height=y, edit_link=LINK])}}' if args.empty?

        v = args[0]

        raise '<link> is not a Google document.' unless v.start_with? 'https://docs.google.com/'

        src = v.dup
        unless src.include? '?'
          src << if src.include? 'edit'
                   '?rm=minimal'
                 else
                   '?widget=true&headers=false'
                 end
        end

        s = []
        s << tag.iframe(width: width, height: height, src: src, frameborder: 0, allowfullscreen: 'true')
        if options[:edit_link].present?
          raise '<edit_link> is not a Google document.' unless options[:edit_link].start_with? 'https://docs.google.com/'

          s << tag.br
          s << link_to(font_awesome_icon('fab_google-drive', post_text: :label_open_in_google_docs),
                       options[:edit_link],
                       class: 'external')
        end

        safe_join s
      end
    end
  end
end
