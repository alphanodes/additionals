# frozen_string_literal: true

class DashboardContentWelcome < DashboardContent
  TYPE_NAME = 'WelcomeDashboard'

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => %w[welcome legacy_left],
      'right' => ['legacy_right']
    }
  end
end
