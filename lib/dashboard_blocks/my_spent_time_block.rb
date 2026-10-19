# frozen_string_literal: true

module DashboardBlocks
  class MySpentTimeBlock < Base
    block_id 'my_spent_time'
    label :label_my_spent_time
    permission :log_time
    setting :days, type: :integer, label: :label_day_plural, min: 1, max: 365, required: true, default: 7

    # Hours of the user today and in the last days, in the project if any
    def data
      @data ||= begin
        today = user.today
        scope = TimeEntry.where user_id: user.id
        scope = scope.where project_id: project.id if project
        { days:,
          today_hours: scope.where(spent_on: today).sum(:hours).to_f,
          days_hours: scope.where(spent_on: (today - (days - 1))..today).sum(:hours).to_f }
      end
    end

    def export_data
      data
    end
  end
end
