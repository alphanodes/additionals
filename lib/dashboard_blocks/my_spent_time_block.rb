# frozen_string_literal: true

module DashboardBlocks
  class MySpentTimeBlock < Base
    block_id 'my_spent_time'
    label :label_my_spent_time
    permission :log_time
    setting :days, type: :integer, label: :label_day_plural, min: 1, max: 365, default: 7
  end
end
