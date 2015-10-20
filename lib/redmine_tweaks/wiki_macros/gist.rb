# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

# Gist wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc 'gist embed'
      # Register gist macro
      macro :gist do |_obj, args|
        javascript_tag(nil, src: "https://gist.github.com/#{args[0]}.js") unless args.empty?
      end
    end
  end
end
