# frozen_string_literal: true

module AdditionalsIssuesHelper
  def author_options_for_select(project, entity = nil, permission = nil)
    scope = project.present? ? project.users.visible : User.active.visible
    scope = scope.with_permission permission, project unless permission.nil?
    authors = scope.sorted.to_a

    unless entity.nil?
      current_author_found = authors.detect { |u| u.id == entity.author_id_was }
      if current_author_found.blank?
        current_author = User.find_by id: entity.author_id_was
        authors << current_author if current_author
      end
    end

    s = []
    return s unless authors.any?

    s << tag.option("<< #{l :label_me} >>", value: User.current.id) if authors.include? User.current

    if entity.nil?
      s << options_from_collection_for_select(authors, 'id', 'name')
    else
      s << tag.option(entity.author, value: entity.author_id, selected: true) if entity.author && authors.exclude?(entity.author)
      s << options_from_collection_for_select(authors, 'id', 'name', entity.author_id)
    end
    safe_join s
  end

  def show_issue_change_author?(issue)
    if issue.new_record? && User.current.allowed_to?(:change_new_issue_author, issue.project) ||
       issue.persisted? && User.current.allowed_to?(:edit_issue_author, issue.project)
      true
    end
  end
end
