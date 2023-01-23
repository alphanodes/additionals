# frozen_string_literal: true

module AdditionalsCommonJournalsHelper
  def render_author_indicator(entry, journal)
    return if entry.author_id != journal.user_id

    tag.span l(:field_author),
             title: l(:label_user_is_author_of, entity: l("label_#{entry.class.name.underscore}_genitive")),
             class: 'badge badge-author'
  end
end
