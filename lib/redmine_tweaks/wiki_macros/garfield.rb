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

    {{garfield([<yyyy-<mm>-<dd>])}}

    Examples:

    {{garfield}} show strip of the current day
    {{garfield(2014-10-31)}} show strip of 31/12/2014
  EOHELP

      macro :garfield do |_obj, args|
        if args.length > 0
          fail 'The correct usage is {{garfield([<yyyy>-<mm>-<dd>])}}' if args[0].blank? || args.length != 1
          gdate = Date.strptime(args[0], '%Y-%m-%d')
          fail 'invalid date' if gdate.nil?
        else
          gdate = Time.zone.today
        end

        file = RedmineTweaks.get_garfield(gdate)
        image = url_for(controller: 'garfield', action: 'show', name: file[:name])
        content_tag(:img, '', alt: "Garfield strip #{file[:name]}", class: 'garfield', src: image)
      end
    end
  end

  def self.get_garfield(date)
    if Setting.plugin_redmine_tweaks['garfield_source_host'].blank?
      fail 'Missing garfield source setting.'
    end

    filename = "#{date.strftime('%Y')}-#{date.strftime('%m')}-#{date.strftime('%d')}"
    local_path = "#{Rails.root}/tmp/_garfield_#{filename}.jpg".freeze

    # cache file if it doesn't exist
    unless File.file?(local_path)
      Net::HTTP.start(Setting.plugin_redmine_tweaks['garfield_source_host'], use_ssl: true) do |http|
        resp = http.get("/uploads/strips/#{filename}.jpg")
        unless resp.code == '404'
          open(local_path, 'wb') { |file| file.write(resp.body) }
        end
      end
    end
    { name: filename }
  end
end
