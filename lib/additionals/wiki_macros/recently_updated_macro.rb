# frozen_string_literal: true

module Additionals
  module WikiMacros
    module RecentlyUpdatedMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Displays a list of wiki pages that were updated recently.

    Syntax:

      {{recently_updated([days, title=STRING])}}

    Scope:

      This macro only works in wiki page contexts.

    Examples:

      {{recently_updated}} - List last updated pages with default i18n title
      {{recently_updated(15)}} - List last updated pages of the last 15 days with default i18n title
      {{recently_updated(7, title=Recent changes)}} - List with custom title
      {{recently_updated(7, title=false)}} - List without title (also works: title=none, title=off)
        DESCRIPTION

        macro :recently_updated do |obj, args|
          page = obj.page
          return '' unless page&.project

          args, options = extract_macro_options args, :title
          days = args.first&.strip&.to_i || 7
          return '' if days < 1

          pages = WikiPage.joins(:content)
                          .includes(:content)
                          .where(wiki_id: page.wiki_id)
                          .where(wiki_contents: { updated_on: (User.current.today - days).. })
                          .order(wiki_contents: { updated_on: :desc })

          pages = pages.visible(User.current, project: page.project) if pages.respond_to? :visible

          grouped_pages = pages.group_by { |p| p.content.updated_on.to_date }
          return '' if grouped_pages.empty?

          s = []
          # title handling: not specified = i18n default, title=false/none/off = no title, title=text = custom text
          disabled_values = %w[false none off]
          if !options.key?(:title)
            # Parameter not specified → use i18n default
            s << tag.h3(l(:label_recently_updated_pages))
          elsif options[:title].present? && disabled_values.exclude?(options[:title])
            # Parameter specified with value (not disabled) → use custom text
            s << tag.h3(options[:title])
          end
          # else: title=false/none/off → no title

          s += grouped_pages.flat_map do |date, date_pages|
            [
              tag.strong(format_date(date)),
              tag.ul(class: 'wiki-flat') do
                safe_join(
                  date_pages.map do |page_raw|
                    tag.li do
                      link_to(page_raw.content.page.pretty_title,
                              project_wiki_page_path(page_raw.content.page.project, page_raw.content.page.title))
                    end
                  end
                )
              end
            ]
          end

          tag.div safe_join(s), class: 'recently-updated'
        end
      end
    end
  end
end
