# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RecentlyUpdatedMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Displays a list of pages of the current wiki that were updated recently.
    Nothing is shown if no page was updated in this period.

    Syntax:

      {{recently_updated([days, title=STRING, limit=NUMBER])}}

    Parameters:

      :param int days: number of days (default 7)
      :param string title: list title (default "Updated pages"); false, none or off hides it
      :param int limit: maximum number of pages (default no limit)

    Scope:

      This macro only works in wiki page contexts.

    Examples:

      {{recently_updated}} - List pages updated in the last 7 days with default title
      {{recently_updated(15)}} - List pages updated in the last 15 days with default title
      {{recently_updated(7, title=Recent changes)}} - List with custom title
      {{recently_updated(7, title=false)}} - List without title (also works: title=none, title=off)
      {{recently_updated(7, limit=10)}} - List at most 10 pages
        DESCRIPTION

        macro :recently_updated do |obj, args|
          page = obj.page if obj.is_a?(WikiContent) || obj.is_a?(WikiContentVersion)
          raise 'The macro recently_updated can only be used on a wiki page' if page.nil?
          return '' unless page.project

          args, options = extract_macro_options args, :title, :limit
          days = args.first&.strip&.to_i || 7
          return '' if days < 1

          pages = WikiPage.recently_updated page.wiki, days:, limit: options[:limit]

          # title handling: not specified = i18n default, title=false/none/off = no title, title=text = custom text
          title = if options.key? :title
                    options[:title] if options[:title].present? && %w[false none off].exclude?(options[:title])
                  else
                    l :label_recently_updated_pages
                  end

          render_recently_updated_wiki_pages pages, title:
        end
      end
    end
  end
end
