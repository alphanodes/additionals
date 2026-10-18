# frozen_string_literal: true

module DashboardBlocks
  class ActivityBlock < Base
    block_id 'activity'
    label :label_activity
    dashboards :welcome
    async data_method: 'activity_dashboard_data', partial: 'dashboards/blocks/activity'
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 1000
    setting :me_only, type: :boolean, label: :label_only_my_activities
  end
end
