# frozen_string_literal: true

class AdditionalsConf
  SELECT2_INIT_ENTRIES = 30
  API_LIMIT = 100

  class << self
    def api_limit
      @api_limit ||= with_system_default 'API_LIMIT'
    end

    def select2_init_entries
      @select2_init_entries ||= with_system_default 'SELECT2_INIT_ENTRIES'
    end

    def with_system_default(const_var, type: 'string', default: nil)
      if ENV[const_var].present?
        env_var = ENV.fetch const_var
        case type
        when 'bool'
          RedminePluginKit.true? env_var
        when 'array'
          env_var.strip_split ' '
        else
          env_var
        end
      elsif Redmine::Configuration[const_var.downcase].present?
        Redmine::Configuration[const_var.downcase]
      elsif !default.nil?
        default
      else
        const_get const_var
      end
    end
  end
end
