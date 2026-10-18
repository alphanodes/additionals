# frozen_string_literal: true

class DashboardContentProject < DashboardContent
  TYPE_NAME = 'ProjectDashboard'

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => %w[projectinformation projectissues projecttimeentries],
      'right' => %w[projectmembers projectsubprojects]
    }
  end
end
