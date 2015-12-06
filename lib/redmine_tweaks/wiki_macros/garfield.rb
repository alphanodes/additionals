# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

require 'net/http'

# Garfield wiki macros
module RedmineTweaks
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Garfield macro to include garfield strip of the day.

    Syntax:

    {{garfield([<yyyy,<mm>,<dd>])}}

    Examples:

    {{garfield}} show strip of the current day
    {{garfield(2014,10,31)}} show strip of 31/12/2014
  EOHELP

      macro :garfield do |_obj, args|
        case args.length
        when 3 then file = RedmineTweaks.get_garfield(Date.parse(args[2] + '-' + args[1] + '-' + args[0]))
        when 0 then file = RedmineTweaks.get_garfield(Time.zone.today)
        else
          fail 'The correct usage is {{garfield([<yyyy>,<mm>,<dd>])}}'
        end

        image = url_for(controller: 'garfield', action: 'show', name: file[:name], type: file[:type])
        content_tag(:img, '', alt: "Garfield strip #{file[:name]}", class: 'garfield', src: image)
      end
    end
  end

  def self.get_garfield(date)
    yyyy = date.strftime('%Y')
    mm = date.strftime('%m')
    dd = date.strftime('%d')
    yy = date.strftime('%y')
    type = date.sunday? ? 'jpg' : 'gif'
    filename = 'ga' + yy + mm + dd

    host = 'images.ucomics.com'
    local_path = "#{Rails.root}/tmp/_garfield_#{filename}.#{type}"

    # cache file if it doesn't exist
    unless File.file?(local_path)
      Net::HTTP.start(host) do |http|
        resp = http.get('/comics/ga/' + yyyy + '/' + filename + '.' + type)
        unless resp.code == '404'
          open(local_path, 'wb') { |file| file.write(resp.body) }
        end
      end
    end
    { name: filename, type: type }
  end
end
