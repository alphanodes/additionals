# frozen_string_literal: true

class DashboardContentProject < DashboardContent
  TYPE_NAME = 'ProjectDashboard'

  def block_definitions
    blocks = super

    # legacy_left or legacy_right should not be moved to DashboardContent,
    # because DashboardContent is used for areas in other plugins
    blocks['legacy_left'] = { label: l(:label_dashboard_legacy_left),
                              no_settings: true }

    blocks['legacy_right'] = { label: l(:label_dashboard_legacy_right),
                               no_settings: true }

    blocks['projectinformation'] = { label: l(:label_project_information),
                                     no_settings: true,
                                     if: (lambda do |project|
                                       project.description.present? ||
                                       project.homepage.present? ||
                                       project.visible_custom_field_values.any? { |o| o.value.present? }
                                     end),
                                     partial: 'dashboards/blocks/project_information' }

    blocks['projectissues'] = { label: l(:label_issues_summary),
                                no_settings: true,
                                permission: :view_issues,
                                partial: 'dashboards/blocks/project_issues' }

    blocks['projecttimeentries'] = { label: l(:label_time_tracking),
                                     no_settings: true,
                                     permission: :view_time_entries,
                                     partial: 'dashboards/blocks/project_time_entries' }

    blocks['projectmembers'] = { label: l(:label_member_plural),
                                 no_settings: true,
                                 partial: 'projects/members_box' }

    blocks['projectsubprojects'] = { label: l(:label_subproject_plural),
                                     no_settings: true,
                                     partial: 'dashboards/blocks/project_subprojects' }

    blocks
  end

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => %w[projectinformation projectissues projecttimeentries],
      'right' => %w[projectmembers projectsubprojects]
    }
  end
end
