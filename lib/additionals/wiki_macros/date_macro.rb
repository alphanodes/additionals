# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Show date.

  Syntax:

     {{date([TYPE])}}
     TYPE
     - current_date           current date (default)
     - current_date_with_time current date with time
     - current_year           current year
     - current_month          current month
     - current_day            current day
     - current_hour           current hour
     - current_minute         current minute
     - current_weekday        current weekday
     - current_weeknumber     current week number (1 - 52) The week starts with Monday
     - YYYY-MM-DD             e.g. 2018-12-24, which will formated with Redmine date format

   Examples:

      {{date}}
      ...show current date
      {{date(current_year)}}
      ...show current year
      {{date(current_month)}}
      ...show current month
      {{date(current_weeknumber)}}
      ...show current week number
      DESCRIPTION

      macro :date do |_obj, args|
        type = if args.present?
                 args[0]
               else
                 'current_date'
               end

        d = Additionals.now_with_user_time_zone
        date_result = case type
                      when 'current_date'
                        format_date User.current.today
                      when 'current_date_with_time'
                        format_time d, true
                      when 'current_year'
                        d.year
                      when 'current_month'
                        d.month
                      when 'current_day'
                        d.day
                      when 'current_hour'
                        d.hour
                      when 'current_minute'
                        d.min
                      when 'current_weekday'
                        day_name d.wday
                      when 'current_weeknumber'
                        User.current.today.cweek
                      else
                        format_date type.to_date
                      end

        tag.span date_result, class: 'current-date'
      end
    end
  end
end
