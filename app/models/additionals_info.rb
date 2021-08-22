# frozen_string_literal: true

class AdditionalsInfo
  include Redmine::I18n

  class << self
    def system_infos
      { system_info: { label: l(:label_system_info), value: system_info },
        system_uptime: { label: l(:label_uptime), value: system_uptime } }
    end

    def system_info
      if windows_platform?
        win_info = `wmic os get Caption,CSDVersion,BuildNumber /value`
        return 'unknown' if win_info.blank?

        windows_version = ''
        windows_build = ''
        build_names = %w[BuildNumber CSDVersion]
        win_info.split(/\n+/).each do |line|
          line_info = line.split '='
          if line_info[0] == 'Caption'
            windows_version = line_info[1]
          elsif build_names.include?(line_info[0]) && line_info[1]&.present?
            windows_build = line_info[1]
          end
        end
        "#{windows_version} build #{windows_build}"
      else
        `uname -a`
      end
    end

    def system_uptime(format: :time_tag)
      if windows_platform?
        `net stats srv | find "Statist"`
      elsif File.exist? '/proc/uptime'
        secs = `cat /proc/uptime`.to_i
        min = 0
        hours = 0
        days = 0
        if secs.positive?
          min = (secs / 60).round
          hours = (secs / 3_600).round
          days = (secs / 86_400).round
        end
        if days >= 1
          "#{days} #{l :days, count: days}"
        elsif hours >= 1
          "#{hours} #{l :hours, count: hours}"
        else
          "#{min} #{l :minutes, count: min}"
        end
      else
        # this should be work on macOS
        seconds = `sysctl -n kern.boottime | awk '{print $4}'`.tr ',', ''
        so = DateTime.strptime seconds.strip, '%s'
        if so.present?
          if format == :datetime
            so
          else
            ApplicationController.helpers.time_tag so
          end
        else
          days = `uptime | awk '{print $3}'`.to_i.round
          "#{days} #{l :days, count: days}"
        end
      end
    end

    def windows_platform?
      /cygwin|mswin|mingw|bccwin|wince|emx/.match? RUBY_PLATFORM
    end
  end
end
