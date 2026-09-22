# frozen_string_literal: true

module Additionals
  module WikiMacros
    module DateMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display the current date (in the time zone of the current user) or a given date.

    Syntax:

      {{date([TYPE])}}
      TYPE
      - current_date           current date (default)
      - current_date_with_time current date with time
      - current_year           current year
      - current_month          current month (number)
      - current_day            current day of month
      - current_hour           current hour
      - current_minute         current minute
      - current_weekday        name of the current weekday
      - current_weeknumber     current ISO week number (1 - 53), weeks start on Monday
      - YYYY-MM-DD             e.g. 2018-12-24, shown in the Redmine date format

    Examples:

        {{date}}
        ...show current date
        {{date(current_year)}}
        ...show current year
        {{date(current_weeknumber)}}
        ...show current week number
        {{date(2018-12-24)}}
        ...show 2018-12-24 in the Redmine date format
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
end
