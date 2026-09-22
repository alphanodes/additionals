# frozen_string_literal: true

module Additionals
  module WikiMacros
    module AsciinemaMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
     Embed an asciinema.org terminal recording (asciicast).

     Syntax: {{asciinema(cast_id)}}

     Parameters:
      cast_id (string) - asciinema.org asciicast id

     Scope:
      This macro works in all text fields with formatting support.

     Examples:
      show asciinema.org cast_id 113463
      {{asciinema(113463)}}
        DESCRIPTION

        macro :asciinema do |_obj, args|
          raise 'The correct usage is {{asciinema(<cast_id>)}}' if args.empty?

          javascript_tag nil, id: "asciicast-#{args[0]}", src: "//asciinema.org/a/#{args[0]}.js", async: true
        end
      end
    end
  end
end
