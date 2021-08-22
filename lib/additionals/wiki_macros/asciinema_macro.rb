# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc 'asciinema embed'

      macro :asciinema do |_obj, args|
        raise 'The correct usage is {{asciinema(<cast_id>)}}' if args.empty?

        javascript_tag nil, id: "asciicast-#{args[0]}", src: "//asciinema.org/a/#{args[0]}.js", async: true
      end
    end
  end
end
