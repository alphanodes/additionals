# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015 AlphaNodes GmbH

require 'net/http'
require_dependency 'redmine_tweaks_helper'

module RedmineTweaks
  
  Redmine::WikiFormatting::Macros.register do
    
    
    desc <<-EOHELP
Garfield macro to include garfield strip of the day.

  Syntax:

  {{garfield([<yyyy,<mm>,<dd>])}}

  Examples:

  {{garfield}} show strip of the current day
  {{garfield(2014,10,31)}} show strip of 31/12/2014
EOHELP

    # Register garfield macro
    macro :garfield do |obj, args|
      
      case args.length
      when 3 then file = RedmineTweaks.get_garfield(Date.parse(args[2] + '-'+ args[1] + '-' + args[0]))
      when 0 then file = RedmineTweaks.get_garfield(Date.today)
      else
        out = "<pre>Error in garfield macro. The correct usage is {{garfield([&lt;yyyy&gt;,&lt;mm&gt;,&lt;dd&gt;])}}.</pre>"
      end

      image = url_for(:controller=>'garfield', :action=>'show', :name => file[:name], :type => file[:type])
      content_tag(:img, '', :alt=>"Garfield strip #{file[:name]}", :class=>'garfield', :src=>image)
    end
  end
    
  def self.get_garfield(date)
    yyyy = date.strftime("%Y")
    mm = date.strftime("%m")
    dd = date.strftime("%d")
    yy = date.strftime("%y")
    type = date.sunday? ? 'jpg' : 'gif'
    filename = 'ga' + yy + mm + dd;

    host = 'images.ucomics.com'
    local_path = "#{Rails.root}/tmp/_garfield_#{filename}.#{type}"

    # cache file if it doesn't exist
    unless File.file?(local_path)
      Net::HTTP.start(host) { |http|
        resp = http.get('/comics/ga/' + yyyy + '/' + filename + '.' + type)
        unless resp.code=="404"
          open(local_path, 'wb' ) { |file|file.write(resp.body) }
        end
      }
    end
    { :name => filename, :type => type }
  end
end
