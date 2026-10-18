# frozen_string_literal: true

module DashboardBlocks
  class ProjectSubprojectsBlock < Base
    block_id 'projectsubprojects'
    label :label_subproject_plural
    dashboards :project
    partial 'dashboards/blocks/project_subprojects'
    no_settings!
  end
end
