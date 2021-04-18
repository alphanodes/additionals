# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Creates link to twitter account page or topic.
    {{twitter(name)}}
      DESCRIPTION

      macro :twitter do |_obj, args|
        raise 'The correct usage is {{twitter(<name>)}}' if args.empty?

        name = args[0].strip
        case name[0]
        when '@'
          link_to(font_awesome_icon('fab_twitter', post_text: name),
                  "https://twitter.com/#{name[1..-1]}",
                  class: 'external twitter',
                  title: l(:label_twitter_account))
        when '#'
          link_to(font_awesome_icon('fab_twitter-square', post_text: name),
                  "https://twitter.com/hashtag/#{name[1..-1]}",
                  class: 'external twitter',
                  title: l(:label_twitter_hashtag))
        else
          link_to(font_awesome_icon('fab_twitter', post_text: " @#{name}"),
                  "https://twitter.com/#{name}",
                  class: 'external twitter',
                  title: l(:label_twitter_account))
        end
      end
    end
  end
end
