# frozen_string_literal: true

module ProjectsSettingsIssues
  Deface::Override.new virtual_path: 'projects/settings/_issues',
                       name: 'add-project-issue-settings',
                       insert_before: 'div.box.tabular',
                       original: 'f14b1e325de2e0de0e81443716705547a6c8471f',
                       text: '<%= call_hook :view_projects_issue_settings, f: f, project: @project %>'
end
