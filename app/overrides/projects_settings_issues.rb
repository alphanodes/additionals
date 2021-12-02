# frozen_string_literal: true

module ProjectsSettingsIssues
  if Redmine::VERSION.to_s >= '4.3' || Redmine::VERSION.to_s >= '4.2' && Redmine::VERSION.to_s.include?('devel')
    Deface::Override.new virtual_path: 'projects/settings/_issues',
                         name: 'add-project-issue-settings',
                         insert_before: 'div.box.tabular',
                         original: 'f14b1e325de2e0de0e81443716705547a6c8471f',
                         text: '<%= call_hook :view_projects_issue_settings, f: f, project: @project %>'
  else
    Deface::Override.new virtual_path: 'projects/settings/_issues',
                         name: 'add-project-issue-settings',
                         insert_before: 'div.box.tabular',
                         original: '468bd73ed808b51fc5589f6c9c23e93a5b7b787a',
                         text: '<%= call_hook :view_projects_issue_settings, f: f, project: @project %>'
  end
end
