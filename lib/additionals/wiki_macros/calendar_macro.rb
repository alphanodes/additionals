# Calendar wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Display calendar (only works on wiki pages)
    Examples:

    {{calendar}}                    show calendar for current date
    {{calendar(year=2014,month=6)}} show calendar for Juni in year 2014
    {{calendar(show_weeks=true)}}   show calendar with week numbers
    {{calendar(select=2015-07-12 2015-07-31, show_weeks=true)}} preselect dates and show week numbers
    {{calendar(select=2016-03-13:2016-03-27)}} preselect dates between 2016/3/13 and 2016/3/27

  EOHELP

      macro :calendar do |_obj, args|
        args, options = extract_macro_options(args, :show_weeks, :year, :month, :select)
        raise 'Only works on wiki page' unless controller_name == 'wiki' && action_name == 'show'

        options[:show_weeks] = 'false' if options[:show_weeks].blank?
        options[:year] = Time.zone.now.year.to_s if options[:year].blank?
        options[:month] = Time.zone.now.month.to_s if options[:month].blank?
        options[:month] = options[:month].to_i - 1

        selected = ''
        selected = Additionals.convert_string2date(options[:select]) if options[:select].present?

        locale = User.current.language.blank? ? ::I18n.locale : User.current.language
        # not more then 30 calendars per page are expected
        id = (0..30).to_a.sort { rand - 0.5 } [1]
        render partial: 'wiki/calendar_macros', locals: { options: options, locale: locale, id: id, selected: selected }
      end
    end
  end

  def self.convert_string2date(string)
    selected = if string.include? ':'
                 convert_string2period(string)
               else
                 convert_string2dates(string)
               end
    selected.join(', ')
  end

  def self.convert_string2period(string)
    s = string.split ':'
    raise 'missing date' if s[0].blank? || s[1].blank?
    tstart = Date.strptime(s[0], '%Y-%m-%d')
    raise 'invalid start date' if tstart.nil?
    tend = Date.strptime(s[1], '%Y-%m-%d')
    raise 'invalid start date' if tend.nil?
    (tstart..tend).map { |date| "new Date(#{date.year},#{date.month - 1},#{date.mday})" }
  end

  def self.convert_string2dates(string)
    selected = []
    s = string.split
    s.each do |d|
      con = Date.strptime(d, '%Y-%m-%d')
      unless con.nil?
        selected << "new Date(#{con.year},#{con.month - 1},#{con.mday})"
      end
    end
    selected
  end
end
