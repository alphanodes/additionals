# frozen_string_literal: true

class AdditionalsInfo
  include Redmine::I18n

  def system_infos
    infos = { system_info: { label: l(:label_system_info),
                             value: system_info },
              system_uptime: { label: l(:label_uptime),
                               value: system_uptime,
                               api_value: system_uptime(format: :datetime) },
              redmine_plugin_kit: { label: 'Redmine Plugin Kit',
                                    value: RedminePluginKit::VERSION } }

    Array(Redmine::Configuration['system_infos_vars']).each do |var|
      next unless ENV.key? var

      infos[var] = { value: ENV.fetch(var, nil) }
    end

    Array(Redmine::Configuration['system_infos_bool_vars']).each do |var|
      next unless ENV.key? var

      infos[var] = { value: RedminePluginKit.true?(ENV.fetch(var, nil)) }
    end

    infos
  end

  def system_info
    if Redmine::Platform.mswin?
      unkwown_windows = 'Windows'
      begin
        win_info = `wmic os get Caption,CSDVersion,BuildNumber /value`
        win_info = Redmine::CodesetUtil.replace_invalid_utf8 win_info
        return unkwown_windows if win_info.blank?
      rescue StandardError
        return unkwown_windows
      end

      windows_version = ''
      windows_build = ''
      build_names = %w[BuildNumber CSDVersion]
      win_info.split(/\n+/).each do |line|
        line_info = line.split '='
        if line_info[0] == 'Caption'
          windows_version = line_info[1]
        elsif build_names.include?(line_info[0]) && line_info[1].present?
          windows_build = line_info[1]
        end
      end
      "#{windows_version} build #{windows_build}"
    else
      `uname -a`
    end
  end

  def system_uptime(format: :time_tag)
    if Redmine::Platform.mswin?
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
end
