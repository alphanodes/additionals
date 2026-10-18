# frozen_string_literal: true

module DashboardBlocks
  # Only with something to show: a description, homepage or custom field value
  class ProjectInformationBlock < Base
    block_id 'projectinformation'
    label :label_project_information
    dashboards :project
    partial 'dashboards/blocks/project_information'
    no_settings!

    def available?
      return false unless project

      project.description.present? ||
        project.homepage.present? ||
        project.visible_custom_field_values.any? { |value| value.value.present? }
    end
  end
end
