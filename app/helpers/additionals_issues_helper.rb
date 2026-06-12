# frozen_string_literal: true

module AdditionalsIssuesHelper
  def author_options_for_select(project, entity = nil, permission = nil)
    scope = project.present? ? project.users.visible : User.active.visible
    scope = scope.with_permission permission, project if permission
    authors = scope.sorted.to_a

    if entity
      current_author_found = authors.detect { |u| u.id == entity.author_id_was }
      if current_author_found.blank?
        current_author = User.find_by id: entity.author_id_was
        authors << current_author if current_author
      end
    end

    s = []
    return s unless authors.any?

    s << tag.option("<< #{l :label_me} >>", value: User.current.id) if authors.include? User.current

    if entity
      s << tag.option(entity.author, value: entity.author_id, selected: true) if entity.author && authors.exclude?(entity.author)
      s << options_from_collection_for_select(authors, 'id', 'name', entity.author_id)
    else
      s << options_from_collection_for_select(authors, 'id', 'name')
    end
    safe_join s
  end

  def show_issue_change_author?(issue)
    issue.new_record? && User.current.allowed_to?(:change_new_issue_author, issue.project) ||
      issue.persisted? && User.current.allowed_to?(:edit_issue_author, issue.project)
  end

  def render_assign_to_me_button(issue)
    link_to svg_icon_tag('assign'),
            issue_assign_to_me_path(issue),
            method: :put,
            class: 'icon assign-to-me',
            title: l(:button_assign_to_me)
  end

  def show_render_assign_to_me_button(issue)
    User.current.logged? &&
      Additionals.setting?(:issue_assign_to_me) &&
      issue.editable? &&
      issue.safe_attribute?('assigned_to_id') &&
      issue.assigned_to_id != User.current.id &&
      issue.project.assignable_users(issue.tracker).exists?(id: User.current.id)
  end

  # Render the issue category as a link to the issue list of the issue's
  # project, filtered by this category. Falls back to the plain (escaped)
  # category name when the issue_link_category setting is disabled - which
  # matches Redmine core's default rendering (format_object -> h(name)).
  # The category can be passed in to reuse an already loaded association
  # (e.g. the preloaded value in a query column) and avoid an extra query.
  def link_to_issue_category(issue, category: nil)
    category ||= issue.category
    return '' if category.nil?
    return h category.name unless Additionals.setting? :issue_link_category

    link_to category.name,
            project_issues_path(issue.project, set_filter: 1, category_id: category.id),
            class: 'issue-category-link',
            title: l(:label_issue_link_category_title)
  end
end
