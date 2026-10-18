# frozen_string_literal: true

module DashboardBlocks
  class ProjectTimeEntriesBlock < Base
    block_id 'projecttimeentries'
    label :label_time_tracking
    dashboards :project
    permission :view_time_entries
    partial 'dashboards/blocks/project_time_entries'
    no_settings!
  end
end
