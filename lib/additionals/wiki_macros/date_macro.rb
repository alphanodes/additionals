# Date wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Display current dates.  Examples:

    {{current_year}}       current year
    {{current_month}}      current month
    {{current_day}}        current day
    {{current_day}}        current day
    {{current_hour}}       current hour
    {{current_minute}}     current minute
    {{current_weekday}}    current weekday
    {{current_weeknumber}} current week number (1 - 52) The week starts with Monday
  EOHELP

      macro :current_year do |_obj, _args|
        content_tag(:span, Time.zone.now.year, class: 'current-date')
      end

      macro :current_month do |_obj, _args|
        content_tag(:span, Time.zone.now.month, class: 'current-date')
      end

      macro :current_day do |_obj, _args|
        content_tag(:span, Time.zone.now.day, class: 'current-date')
      end

      macro :current_hour do |_obj, _args|
        content_tag(:span, Time.zone.now.hour, class: 'current-date')
      end

      macro :current_min do |_obj, _args|
        @current_date = Time.zone.now.min
        content_tag(:span, Time.zone.now.min, class: 'current-date')
      end

      macro :current_weekday do |_obj, _args|
        content_tag(:span, day_name(Time.zone.now.wday), class: 'current-date')
      end

      macro :current_weeknumber do |_obj, _args|
        content_tag(:span, Time.zone.today.cweek, class: 'current-date')
      end
    end
  end
end
