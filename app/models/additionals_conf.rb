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

    # Retrieves configuration values with flexible override mechanism
    #
    # Priority order (highest to lowest):
    # 1. ENV variable (e.g., export REPORTING_DISABLE_RAILS_LOGGER_DB=1)
    # 2. configuration.yml (e.g., reporting_disable_rails_logger_db: true)
    # 3. default parameter (can be dynamic, e.g., Rails.env.test?)
    # 4. Constant from this class
    #
    # @param const_var [String] Variable name in UPPERCASE (e.g., 'API_LIMIT')
    # @param type [String] 'string', 'bool' (via RedminePluginKit.true?), 'array' (space-separated)
    # @param default [Object] Default value if not found in ENV or configuration.yml
    #
    # @example Boolean with environment-aware default
    #   AdditionalsConf.with_system_default 'REPORTING_DISABLE_RAILS_LOGGER_DB',
    #                                        type: 'bool',
    #                                        default: Rails.env.test?
    #   # → Test: true (disabled), Production: false (enabled), ENV/config.yml overrides
    #
    # NOTE: ENV uses UPPERCASE, configuration.yml uses lowercase (e.g., reporting_disable_rails_logger_db)
    #
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
