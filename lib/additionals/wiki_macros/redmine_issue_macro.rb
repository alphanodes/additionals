# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RedmineIssueMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
   Link to a redmine.org issue

   Syntax:

   {{redmine_issue(id or url [, title=TITLE])}}

   Parameters:

    :param string id: issue id from redmine.org
    :param string url: this can be an absolute path to an redmine.org issue or an issue id
    :param string title: title of link to display

   Examples:

      Link to redmine.org issue with issue id:
      {{redmine_issue(1333)}}
      Link to redmine.org issue with issue id and anchor:
      {{redmine_issue(1333#note-6)}}
      Link to redmine.org issue with absolute url:
      {{redmine_issue(http://www.redmine.org/issues/12066)}}
        DESCRIPTION

        macro :redmine_issue do |_obj, args|
          raise 'The correct usage is {{redmine_issue(<id>)}}' if args.empty?

          args, options = extract_macro_options args, :title
          raw_link = args[0].to_s.strip

          if !/\A\d+\z/.match(raw_link[0])
            # https://www.redmine.org/issues/12066#note-7
            if raw_link =~ %r{redmine.org/issues/([0-9].+?)#(.*)} ||
               raw_link =~ %r{redmine.org/issues/([0-9].+)}
              link_name = Regexp.last_match 1
              link = raw_link.gsub 'http://', 'https://'
            else
              raise 'The correct usage is {{redmine_issue(<id>)}}'
            end
          elsif raw_link =~ /([0-9].+?)\D/
            # ID with parameters
            link_name = Regexp.last_match 1
            link = "https://www.redmine.org/issues/#{raw_link}"
          else
            # just ID
            link_name = raw_link
            link = "https://www.redmine.org/issues/#{raw_link}"
          end

          link_options = { class: 'redmine-link' }
          link_options[:title] = options[:title].presence || l(:label_redmine_org_issue)

          link_to_external "##{link_name}", link, **link_options
        end
      end
    end
  end
end
