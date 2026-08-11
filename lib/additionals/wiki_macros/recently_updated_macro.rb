# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RecentlyUpdatedMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Displays a list of wiki pages that were updated recently.

    Syntax:

      {{recently_updated([days, title=STRING, limit=NUMBER])}}

    Scope:

      This macro only works in wiki page contexts.

    Examples:

      {{recently_updated}} - List last updated pages with default i18n title
      {{recently_updated(15)}} - List last updated pages of the last 15 days with default i18n title
      {{recently_updated(7, title=Recent changes)}} - List with custom title
      {{recently_updated(7, title=false)}} - List without title (also works: title=none, title=off)
      {{recently_updated(7, limit=10)}} - List at most 10 pages
        DESCRIPTION

        macro :recently_updated do |obj, args|
          page = obj.page
          return '' unless page&.project

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
