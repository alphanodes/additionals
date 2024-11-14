# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RedditMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Creates link to reddit.
      {{reddit(<subject or user name>)}}

    Examples:

     {{reddit(redmine)}} or {{reddit(r/redmine)}} - Show link to reddit subject `r/redmine`
     {{reddit(u/redmine)}} - Show link to reddit user profile `u/redmine`
        DESCRIPTION

        macro :reddit do |_obj, args|
          raise 'The correct usage is {{reddit(<name>)}}' if args.empty?

          name = args[0].strip

          case name[0..1]
          when 'r/'
            link_to_external svg_icon_tag('reddit', label: name),
                             "https://www.reddit.com/#{name}",
                             class: 'icon reddit',
                             title: l(:label_reddit_subject)
          when 'u/'
            link_to_external svg_icon_tag('reddit', label: name),
                             "https://www.reddit.com/username/#{name[2..]}",
                             class: 'icon reddit',
                             title: l(:label_reddit_user_account)
          else
            name = "r/#{name}"
            link_to_external svg_icon_tag('reddit', label: name),
                             "https://www.reddit.com/#{name}",
                             class: 'icon reddit',
                             title: l(:label_reddit_subject)
          end
        end
      end
    end
  end
end
