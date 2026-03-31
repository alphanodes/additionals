# frozen_string_literal: true

module AdditionalsGlobalSearchHelper
  def global_search_data
    { controller: 'global-search',
      'global-search-url-value': search_global_search_path,
      'global-search-project-id-value': @project&.identifier,
      'global-search-project-name-value': @project&.name,
      'no-results': l(:label_no_data),
      hint: l(:label_search),
      loading: l(:label_loading),
      'search-label': l(:label_search),
      'recent-searches': l(:label_global_search_recent_searches),
      'recent-projects': l(:label_global_search_recent_projects),
      'clear-all': l(:label_global_search_clear_all),
      'scope-all': l(:label_global_search_in_all_projects),
      'scope-bookmarks': l(:label_global_search_in_my_bookmarks),
      'tab-all': l(:label_all).capitalize,
      'search-types': global_search_types.to_json,
      'search-types-project': (@project ? global_search_types(project: @project) : nil)&.to_json,
      'semantic-icon': svg_icon_tag('robot', size: 16, icon_only: true).to_str,
      'core-search-url': search_path,
      action: 'click->global-search#closeOnOverlay' }
  end

  def global_search_types(project: nil)
    types = Redmine::Search.available_search_types.dup

    if project
      types.delete 'projects'
      types.select! { |t| User.current.allowed_to? :"view_#{t}", project }
    end

    types.map do |type|
      { id: type, label: l("label_#{type.singularize}_plural", default: type.humanize) }
    end
  end
end
