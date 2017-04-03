# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

# Twitter wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
      Creates link to twitter account page.
        {{twitter(user_name)}}
  EOHELP
      macro :twitter do |_obj, args|
        raise 'The correct usage is {{twitter(<user_name>)}}' if args.empty?
        user_name = args[0].strip
        link_to(h("@#{user_name}"), "https://twitter.com/#{user_name}", class: 'external twitter')
      end
    end
  end
end
