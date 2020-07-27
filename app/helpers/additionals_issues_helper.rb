module AdditionalsIssuesHelper
  def author_options_for_select(project, issue = nil)
    authors = if project.present?
                project.users.sorted
              else
                Principal.active.where(type: 'User').sorted
              end

    s = []
    return s unless authors.any?

    s << tag.option("<< #{l(:label_me)} >>", value: User.current.id) if authors.include?(User.current)

    if issue.nil?
      s << options_from_collection_for_select(authors, 'id', 'name')
    else
      s << tag.option(issue.author, value: issue.author_id, selected: true) if issue.author && authors.exclude?(issue.author)
      s << options_from_collection_for_select(authors, 'id', 'name', issue.author_id)
    end
    safe_join(s)
  end

  def show_issue_change_author?(issue)
    if issue.new_record? && User.current.allowed_to?(:change_new_issue_author, issue.project) ||
       issue.persisted? && User.current.allowed_to?(:edit_issue_author, issue.project)
      true
    end
  end
end
