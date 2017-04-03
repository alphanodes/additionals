# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

# Gist wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc 'gist embed'

      macro :gist do |_obj, args|
        raise 'The correct usage is {{gist(<gist_id>)}}' if args.empty?
        javascript_tag(nil, src: "https://gist.github.com/#{args[0]}.js")
      end
    end
  end
end
