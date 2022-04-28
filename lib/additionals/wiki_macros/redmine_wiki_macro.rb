# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RedmineWikiMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
  Link to redmine.org wiki page

  Syntax:

    {{redmine_wiki(url [, name=NAME, title=TITLE])}}

  Parameters:

    :param string url: this can be an absolute path to an redmine.org issue or an issue id
    :param string name: name to display for link, if not specified, wiki page name is used
    :param string title: title of link to display

  Examples:

    Link to redmine.org wiki page with page name:
    {{redmine_wiki(RedmineInstall)}}
    Link to redmine.org wiki page with page name and anchor:
    {{redmine_wiki(FAQ#How-do-I-create-sub-pages-parentchild-relationships-in-the-wiki)}}
    Link to redmine.org wiki page with absolute url:
    {{redmine_wiki(https://www.redmine.org/projects/redmine/wiki/RedmineInstall)}}
        DESCRIPTION

        macro :redmine_wiki do |_obj, args|
          raise 'The correct usage is {{redmine_wiki(<page>)}}' if args.empty?

          args, options = extract_macro_options args, :title, :name

          raw_link = args[0].to_s.strip

          if raw_link[0..3] == 'http'
            start_pos = raw_link.index 'redmine.org/projects/redmine/wiki/'
            raise 'The correct usage is {{redmine_wiki(<page>)}}' if start_pos.nil? || start_pos.zero?

            options[:name] = raw_link[(start_pos + 34)..] if options[:name].blank?
            link = raw_link.gsub 'http://', 'https://'
          elsif /\w/.match?(raw_link[0])
            options[:name] = raw_link if options[:name].blank?
            link = "https://www.redmine.org/projects/redmine/wiki/#{Wiki.titleize raw_link}"
          else
            raise 'The correct usage is {{redmine_wiki(<page>)}}'
          end

          link_options = { class: 'external redmine-link' }
          link_options[:title] = options[:title].presence || l(:label_redmine_org_wiki)

          link_to options[:name], link, link_options
        end
      end
    end
  end
end
