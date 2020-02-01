if Redmine::VERSION.to_s >= '4.1'
  Deface::Override.new virtual_path: 'projects/show',
                       name: 'view-projects-actions-dropdown-hook',
                       insert_before: 'erb[loud]:contains("link_to_if_authorized l(:label_settings)")',
                       original: 'da5a3461fab48e7198701c3e7e5a8e98295d9e3a',
                       text: '<%= call_hook(:view_projects_show_actions_dropdown, project: @project) %>'
  Deface::Override.new virtual_path: 'projects/show',
                       name: 'view-projects-show-bottom-hook',
                       insert_after: 'div.splitcontent',
                       original: '626f6ed11aca41d7d9cad307d433ec433c450962',
                       text: '<%= call_hook(:view_projects_show_bottom, project: @project) %>'
else
  Deface::Override.new virtual_path: 'projects/show',
                       name: 'view-projects-show-bottom-hook',
                       insert_after: 'div.splitcontentright',
                       original: '8cd4d1b38e8afcb4665dbfea661b7048fbd92cf7',
                       text: '<%= call_hook(:view_projects_show_bottom, project: @project) %>'
end
