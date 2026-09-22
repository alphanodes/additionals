# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GistMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Embed a GitHub gist.

    Syntax:

      {{gist(gist)}}

    Parameters:

      :param string gist: gist id, with or without GitHub user name

    Examples:
      {{gist(6737338)}} - show GitHub gist ``6737338`` (without user name)
      {{gist(plentz/6737338)}} - show GitHub gist ``plentz/6737338`` (with user name)
        DESCRIPTION

        macro :gist do |_obj, args|
          raise 'The correct usage is {{gist(<gist_id>)}}' if args.empty?

          javascript_tag nil, src: "https://gist.github.com/#{args[0]}.js"
        end
      end
    end
  end
end
