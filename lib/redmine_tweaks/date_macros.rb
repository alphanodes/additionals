# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

module RedmineTweaks
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

    macro :current_year do |obj, args|
      @current_date = Time.now.year
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_month do |obj, args|
      @current_date = Time.now.month
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_day do |obj, args|
      @current_date = Time.now.day
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_hour do |obj, args|
      @current_date = Time.now.hour
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_min do |obj, args|
      @current_date = Time.now.min
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_weekday do |obj, args|
      @current_date = day_name Time.now.wday
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end

    macro :current_weeknumber do |obj, args|
      @current_date = Date.today.cweek
      render partial: 'wiki/date_macros', locals: { current_date: @current_date }
    end
  end
end
