# Recently updated wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
      Displays a list of pages that were updated recently.
        {{recently_updated}}
        {{recently_updated([days])}}

        Examples:

        {{recently_updated}}
        ...List last updated pages (of the last 5 days)

        {{recently_updated(15)}}
        ...List last updated pages of the last 15 days

      EOHELP

      macro :recently_updated do |obj, args|
        page = obj.page
        return nil unless page
        project = page.project
        return nil unless project
        days = 5
        days = args[0].strip.to_i unless args.empty?

        return '' if days < 1

        pages = WikiPage
                .includes(:content)
                .where(["#{WikiPage.table_name}.wiki_id = ? AND #{WikiContent.table_name}.updated_on > ?",
                        page.wiki_id, Time.zone.today - days])
                .order("#{WikiContent.table_name}.updated_on desc")
        o = ''
        date = nil
        pages.each do |page_raw|
          content = page_raw.content
          updated_on = Date.new(content.updated_on.year, content.updated_on.month, content.updated_on.day)
          if date != updated_on
            date = updated_on
            o << '<b>' + format_date(date) + '</b><br/>'
          end
          o << link_to(content.page.pretty_title,
                       controller: 'wiki', action: 'show', project_id: content.page.project, id: content.page.title)
          o << '<br/>'
        end
        content_tag('div', o.html_safe, class: 'recently-updated')
      end
    end
  end
end
