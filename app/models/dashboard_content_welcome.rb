# frozen_string_literal: true

class DashboardContentWelcome < DashboardContent
  TYPE_NAME = 'WelcomeDashboard'

  def block_definitions
    blocks = super

    # legacy_left or legacy_right should not be moved to DashboardContent,
    # because DashboardContent is used for areas in other plugins
    blocks['legacy_left'] = { label: l(:label_dashboard_legacy_left),
                              no_settings: true }

    blocks['legacy_right'] = { label: l(:label_dashboard_legacy_right),
                               no_settings: true }

    blocks['welcome'] = { label: l(:setting_welcome_text),
                          no_settings: true,
                          partial: 'dashboards/blocks/welcome' }

    blocks['activity'] = { label: l(:label_activity),
                           async: { data_method: 'activity_dashboard_data',
                                    partial: 'dashboards/blocks/activity' } }

    blocks
  end

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => %w[welcome legacy_left],
      'right' => ['legacy_right']
    }
  end
end
