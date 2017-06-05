# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

# Reddit wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
      Creates link to reddit.
        {{reddit(name)}}
  EOHELP
      macro :reddit do |_obj, args|
        raise 'The correct usage is {{reddit(<name>)}}' if args.empty?
        name = args[0].strip

        case name[0..1]
        when 'r/'
          link_to(h(name), "https://www.reddit.com/#{name}", class: 'external reddit', title: l(:label_reddit_subject))
        when 'u/'
          link_to(h(name), "https://www.reddit.com/username/#{name[2..-1]}", class: 'external reddit', title: l(:label_reddit_user_account))
        else
          name = 'r/' + name
          link_to(h(name), "https://www.reddit.com/#{name}", class: 'external reddit', title: l(:label_reddit_subject))
        end
      end
    end
  end
end
