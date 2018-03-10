# Date wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display current dates.  Examples:

    {{current_year}}       current year
    {{current_month}}      current month
    {{current_day}}        current day
    {{current_day}}        current day
    {{current_hour}}       current hour
    {{current_minute}}     current minute
    {{current_weekday}}    current weekday
    {{current_weeknumber}} current week number (1 - 52) The week starts with Monday
  DESCRIPTION

      macro :current_year do |_obj, _args|
        content_tag(:span, User.current.time_zone.now.year, class: 'current-date')
      end

      macro :current_month do |_obj, _args|
        content_tag(:span, User.current.time_zone.now.month, class: 'current-date')
      end

      macro :current_day do |_obj, _args|
        content_tag(:span, User.current.time_zone.now.day, class: 'current-date')
      end

      macro :current_hour do |_obj, _args|
        content_tag(:span, User.current.time_zone.now.hour, class: 'current-date')
      end

      macro :current_min do |_obj, _args|
        content_tag(:span, User.current.time_zone.now.min, class: 'current-date')
      end

      macro :current_weekday do |_obj, _args|
        content_tag(:span, day_name(User.current.time_zone.now.wday), class: 'current-date')
      end

      macro :current_weeknumber do |_obj, _args|
        content_tag(:span, User.current.today.cweek, class: 'current-date')
      end
    end
  end
end
