# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GistMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Embet GitHub gist

    Syntax:

    {{gist(gist)}}

    Parameters:

      :param string gist: gist to display. With or without Github username.

    Examples:
      {{gist(6737338)}} - show Github gist ``6737338`` (without user name)
      {{gist(plentz/6737338)}} - Show Github gist ``plentz/6737338`` (with user name)
        DESCRIPTION

        macro :gist do |_obj, args|
          raise 'The correct usage is {{gist(<gist_id>)}}' if args.empty?

          javascript_tag nil, src: "https://gist.github.com/#{args[0]}.js"
        end
      end
    end
  end
end
