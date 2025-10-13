# frozen_string_literal: true

require 'redmine_plugin_kit'

module Additionals
  VERSION = '4.2.0-main'

  MAX_CUSTOM_MENU_ITEMS = 5
  DEFAULT_MODAL_WIDTH = '350px'
  GOTO_LIST = " \xc2\xbb"
  LIST_SEPARATOR = "#{GOTO_LIST} ".freeze

  SQL_NO_RESULT_CONDITION = '1=0'
  SQL_WITH_TRUE_CONDITION = '1=1'

  include RedminePluginKit::PluginBase

  class << self
    def class_prefix(klass)
      klass_name = klass.is_a?(String) ? klass : klass.name
      klass_name.underscore.tr '/', '_'
    end

    def uri_parser
      defined?(::URI::RFC2396_PARSER) ? ::URI::RFC2396_PARSER : ::URI::DEFAULT_PARSER
    end

    def now_with_user_time_zone(user = User.current)
      if user.time_zone.nil?
        Time.current
      else
        user.time_zone.now
      end
    end

    def time_zone_correct(time, user: User.current)
      timezone = user.time_zone || Time.zone
      timezone.utc_offset - Time.zone.local_to_utc(time).localtime.utc_offset
    end

    def hash_remove_with_default(field, options, default = nil)
      value = nil
      if options.key? field
        value = options[field]
        options.delete field
      elsif !default.nil?
        value = default
      end
      [value, options]
    end

    def single_page_limit
      Setting.per_page_options_array.second || Setting.per_page_options_array.first || 25
    end

    def split_ids(phrase, limit: nil)
      limit ||= single_page_limit
      raw_ids = phrase.strip_split
      ids = []
      raw_ids.each do |id|
        if id.include? '-'
          range = id.split('-').map(&:strip)
          if range.size == 2
            left_id = range.first.to_i
            right_id = range.last.to_i
            min = [left_id, right_id].min
            max = [left_id, right_id].max
            # if range to large, take lowest numbers + last possible number
            ids << if max - min > limit
                     old_max = max
                     max = limit + min - 2
                     ids << (min..max).to_a
                     old_max
                   else
                     (min..max).to_a
                   end
          end
        else
          ids << id.to_i
        end
      end
      ids.flatten!
      ids.uniq!
      ids.take limit
    end

    def max_live_search_results
      if setting(:max_live_search_results).present?
        setting(:max_live_search_results).to_i
      else
        50
      end
    end

    def debug(message = 'running', console: false)
      if console
        RedminePluginKit::Debug.msg message
      else
        RedminePluginKit::Debug.log message
      end
    end

    private

    def setup
      RenderAsync.configuration.jquery = true

      loader.add_patch %w[ApplicationController
                          AutoCompletesController
                          Issue
                          TimeEntry
                          Mailer
                          Project
                          ProjectQuery
                          Wiki
                          ProjectsController
                          WelcomeController
                          ReportsController
                          SettingsController
                          Principal
                          Query
                          QueryFilter
                          Role
                          User
                          UserPreference]

      loader.add_helper %w[Issues
                           Wiki
                           CustomFields]

      loader.add_helper({ controller: 'Issues', helper: 'AdditionalsCommonJournals' })

      loader.add_patch [{ target: Redmine::Views::LabelledFormBuilder, patch: 'LabelledFormBuilder' }]

      loader.add_global_helper [Additionals::Helpers,
                                AdditionalsIconsHelper,
                                AdditionalsFontawesomeHelper,
                                AdditionalsMenuHelper,
                                AdditionalsSelect2Helper]

      Redmine::WikiFormatting.format_names.each do |format|
        case format
        when 'common_mark'
          loader.add_patch [{ target: Redmine::WikiFormatting::CommonMark::Formatter, patch: 'FormatterCommonMark' }]
          loader.add_patch [{ target: Redmine::WikiFormatting::CommonMark::Helper, patch: 'FormattingHelper' }]
        when 'textile'
          loader.add_patch [{ target: Redmine::WikiFormatting::Textile::Formatter, patch: 'FormatterTextile' },
                            { target: Redmine::WikiFormatting::Textile::Helper, patch: 'FormattingHelper' }]
        end
      end

      # Clients
      loader.require_files File.join('wiki_formatting', 'common_mark', '**/*_filter.rb')

      # Apply patches and helper
      loader.apply!

      # Macros
      loader.load_macros!

      # Load view hooks
      loader.load_view_hooks!
    end
  end
end

class String
  def strip_split(sep = ',')
    split(sep).map(&:strip).compact_blank
  end
end

class Array
  # alias for join with ', ' as seperator
  def to_comma_list
    join ', '
  end
end
