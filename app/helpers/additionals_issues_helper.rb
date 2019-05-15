module AdditionalsIssuesHelper
  def issue_author_options_for_select(project, issue = nil)
    authors = project.users.sorted
    s = []
    return s unless authors.any?

    s << content_tag('option', "<< #{l(:label_me)} >>", value: User.current.id) if authors.include?(User.current)

    if issue.nil?
      s << options_from_collection_for_select(authors, 'id', 'name')
    else
      s << content_tag('option', issue.author, value: issue.author_id, selected: true) if issue.author && !authors.include?(issue.author)
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
