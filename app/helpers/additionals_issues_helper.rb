module AdditionalsIssuesHelper
  def issue_author_options_for_select(project, issue = nil)
    authors = project.users.sort
    s = []

    if authors.include?(User.current)
      s << content_tag('option', "<< #{l(:label_me)} >>", value: User.current.id)
    end

    if issue.nil?
      s << options_from_collection_for_select(authors, 'id', 'name')
    else
      authors.unshift(issue.author) if issue.author && !authors.include?(issue.author)
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

  def issue_auto_assign(context)
    return if Additionals.settings[:issue_auto_assign].blank? ||
              Additionals.settings[:issue_auto_assign_status].blank? ||
              Additionals.settings[:issue_auto_assign_role].blank?
    if context[:params][:issue][:assigned_to_id].blank? &&
       Additionals.settings[:issue_auto_assign_status].include?(context[:params][:issue][:status_id].to_s)
      context[:issue].assigned_to_id = context[:issue].auto_assign_user
    end
  end
end
