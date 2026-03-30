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
      'core-search-url': search_path,
      action: 'click->global-search#closeOnOverlay' }
  end
end
