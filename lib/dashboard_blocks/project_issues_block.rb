# frozen_string_literal: true

module DashboardBlocks
  class ProjectIssuesBlock < Base
    block_id 'projectissues'
    label :label_issues_summary
    dashboards :project
    permission :view_issues
    partial 'dashboards/blocks/project_issues'
    no_settings!
  end
end
