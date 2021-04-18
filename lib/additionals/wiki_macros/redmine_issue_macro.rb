# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Creates link to redmine.org issue.
    {{redmine_issue(1448)}}
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

        link_options = { class: 'external redmine-link' }
        link_options[:title] = options[:title].presence || l(:label_redmine_org_issue)

        link_to "##{link_name}", link, link_options
      end
    end
  end
end
