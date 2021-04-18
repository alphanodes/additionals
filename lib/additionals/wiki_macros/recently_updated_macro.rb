# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Displays a list of pages that were updated recently.
    {{recently_updated}}
    {{recently_updated([days])}}

  Examples:

    {{recently_updated}}
    ...List last updated pages (of the last 5 days)

    {{recently_updated(15)}}
    ...List last updated pages of the last 15 days
      DESCRIPTION

      macro :recently_updated do |obj, args|
        page = obj.page
        return unless page

        project = page.project
        return unless project

        days = 5
        days = args[0].strip.to_i unless args.empty?

        return if days < 1

        pages = WikiPage.joins(:content)
                        .where(wiki_id: page.wiki_id)
                        .where("#{WikiContent.table_name}.updated_on > ?", User.current.today - days)
                        .order("#{WikiContent.table_name}.updated_on desc")

        pages = pages.visible User.current, project: project if pages.respond_to? :visible

        s = []
        date = nil
        pages.each do |page_raw|
          content = page_raw.content
          updated_on = Date.new content.updated_on.year, content.updated_on.month, content.updated_on.day
          if date != updated_on
            date = updated_on
            s << tag.strong(format_date(date))
            s << tag.br
          end
          s << link_to(content.page.pretty_title,
                       controller: 'wiki', action: 'show', project_id: content.page.project, id: content.page.title)
          s << tag.br
        end
        tag.div safe_join(s), class: 'recently-updated'
      end
    end
  end
end
