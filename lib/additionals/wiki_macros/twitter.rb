# Twitter wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
      Creates link to twitter account page or topic.
        {{twitter(name)}}
  EOHELP
      macro :twitter do |_obj, args|
        raise 'The correct usage is {{twitter(<name>)}}' if args.empty?
        name = args[0].strip
        case name[0]
        when '@'
          link_to(h(name), "https://twitter.com/#{name[1..-1]}", class: 'external twitter', title: l(:label_twitter_account))
        when '#'
          link_to(h(name), "https://twitter.com/hashtag/#{name[1..-1]}", class: 'external twitter', title: l(:label_twitter_hashtag))
        else
          link_to(h("@#{name}"), "https://twitter.com/#{name}", class: 'external twitter', title: l(:label_twitter_account))
        end
      end
    end
  end
end
