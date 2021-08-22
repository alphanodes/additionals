# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc 'gist embed'

      macro :gist do |_obj, args|
        raise 'The correct usage is {{gist(<gist_id>)}}' if args.empty?

        javascript_tag nil, src: "https://gist.github.com/#{args[0]}.js"
      end
    end
  end
end
