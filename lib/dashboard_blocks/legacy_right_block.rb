# frozen_string_literal: true

module DashboardBlocks
  class LegacyRightBlock < Base
    block_id 'legacy_right'
    label :label_dashboard_legacy_right
    dashboards :welcome, :project
    no_settings!
  end
end
