# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

# Calendar wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Display calendar.  Examples:

    {{calendar}}                    show calendar for current date
    {{calendar(year=2014,month=6)}} show calendar for Juni in year 2014
    {{calendar(show_weeks=true)}}   show calendar with week numbers
    {{calendar(select=2015-07-12 2015-07-31, show_weeks=true)}} preselect dates and show week numbers

  EOHELP

      macro :calendar do |_obj, args|
        args, options = extract_macro_options(args, :show_weeks, :year, :month, :select)

        options[:show_weeks] = 'false' if options[:show_weeks].blank?
        options[:year] = "#{Time.zone.now.year}" if options[:year].blank?
        options[:month] = "#{Time.zone.now.month}" if options[:month].blank?
        options[:month] = options[:month].to_i - 1

        selected = ''
        selected = RedmineTweaks.convert_string2date(options[:select]) unless options[:select].blank?

        locale = User.current.language.blank? ? ::I18n.locale : User.current.language
        # not more then 30 calendars per page are expected
        id = (0..30).to_a.sort { rand - 0.5 } [1]
        render partial: 'wiki/calendar_macros', locals: { options: options, locale: locale, id: id, selected: selected }
      end
    end
  end

  def self.convert_string2date(string)
    s = string.split
    selected = []
    s.each do |d|
      con = Date.strptime(d, '%Y-%m-%d')
      unless con.nil?
        selected << "new Date(#{con.year},#{con.month - 1},#{con.mday})"
      end
    end
    selected.join(', ')
  end
end
