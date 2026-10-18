# frozen_string_literal: true

module DashboardBlocks
  # Blocks of the welcome page and project overview of core, before dashboards
  class LegacyLeftBlock < Base
    block_id 'legacy_left'
    label :label_dashboard_legacy_left
    dashboards :welcome, :project
    no_settings!
  end
end
