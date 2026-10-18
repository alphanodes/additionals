# frozen_string_literal: true

module DashboardBlocks
  class ActivityBlock < Base
    block_id 'activity'
    label :label_activity
    dashboards :welcome
    async partial: 'dashboards/blocks/activity'
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 1000
    setting :me_only, type: :boolean, label: :label_only_my_activities

    # The latest events by day
    def data
      @data ||= begin
        options = {}
        options[:author] = user if me_only
        options[:project] = project if project
        Redmine::Activity::Fetcher.new(user, options)
                                  .events(nil, nil, limit: max_entries)
                                  .group_by { |event| user.time_to_date event.event_datetime }
      end
    end

    def export_data
      data.map do |day, events|
        { date: day.iso8601,
          events: events.map do |event|
            { type: event.event_type, title: event.event_title, author: event.event_author&.to_s,
              datetime: event.event_datetime.iso8601 }
          end }
      end
    end
  end
end
