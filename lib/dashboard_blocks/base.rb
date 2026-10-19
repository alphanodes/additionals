# frozen_string_literal: true

module DashboardBlocks
  # A block of a dashboard: what it is called, who may add it, on which
  # dashboards and with which settings. A subclass declares it:
  #
  #   class NewsBlock < Base
  #     block_id 'news'
  #     label :label_news_latest
  #     permission :view_news
  #     setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING
  #
  #     def available? = Redmine::AccessControl.active_module?(:news)
  #   end
  #
  # Block classes are loaded at boot, also by db:create and db:migrate: a
  # class (query, chart, service) is therefore named as a string and resolved
  # when the block is used, its class body may not read the database.
  #
  # Settings use the format of Additionals::SettingsSchema. What depends on the
  # user, the project or the data is an instance method (available?,
  # unique_params), the rest is declared on the class and inherited. A rule of
  # a setting is a method named after it, called with the schema:
  #
  #   setting :with_subprojects, type: :boolean
  #
  #   def with_subprojects_available?(_schema) = project.present?
  #
  # <key>_available? decides whether the setting exists (if), <key>_applies?
  # whether it applies to the other values (applies), <key>_values returns the
  # allowed values (values), <key>_offered those a form offers (offered),
  # <key>_default and <key>_label a default and label depending on the context.
  # Each setting gets a reader of its typed value with its default, e.g.
  # block.max_entries.
  class Base
    class_attribute :settings_definitions, instance_writer: false, default: {}
    # Readers of the settings, never a rule even if named like one (e.g. a
    # setting group_threshold_default next to group_threshold)
    class_attribute :setting_readers, instance_writer: false, default: []
    class_attribute :declared_dashboard_types, instance_writer: false
    class_attribute :max_occurs_count, instance_writer: false, default: 1
    class_attribute :block_id_value, :label_value, :permission_value, :partial_value, :async_options,
                    :settings_partial_value, :settings_filter_value, instance_writer: false
    class_attribute :without_settings, :admin_only_value, :generated_settings_form, instance_writer: false, default: false

    extend RedminePluginKit::Extensions::Abstract

    class << self
      # The id stored in the layout of dashboards, it never changes
      def block_id(id = nil)
        id ? self.block_id_value = id.to_s : block_id_value
      end

      # A locale key, or a block for a composed label
      def label(key = nil, &block)
        return self.label_value = block || key if key || block

        label_value.respond_to?(:call) ? label_value.call : I18n.t(label_value)
      end

      # The dashboard types (e.g. :welcome, :project) the block is offered on,
      # all of them without a declaration
      def dashboards(*types)
        self.declared_dashboard_types = types.map(&:to_sym)
      end

      def offered_on?(type)
        declared_dashboard_types.nil? || declared_dashboard_types.include?(type)
      end

      # One permission, or several which all are required
      def permission(name = nil)
        name ? self.permission_value = name : permission_value
      end

      def admin_only!
        self.admin_only_value = true
      end

      def admin_only?
        admin_only_value
      end

      def max_occurs(count = nil)
        count ? self.max_occurs_count = count : max_occurs_count
      end

      # Partial of the block, rendered with the page
      # nil removes the partial of a block a subclass loads after the page
      def partial(*name)
        name.empty? ? partial_value : self.partial_value = name.first
      end

      # Options of a block loaded after the page, see render_async
      def async(**options)
        options.any? ? self.async_options = options : async_options
      end

      # reader: name of the reader of the typed value, e.g. :login_user for a
      # setting user, which would hide the user of the block
      def setting(name, reader: name, **definition)
        name = name.to_sym
        rules = definition.select { |_option, value| value.respond_to? :call }.keys
        raise ArgumentError, "#{self}: setting #{name} declares #{rules.to_comma_list} as lambda, use a method" if rules.any?

        define_setting_reader name, reader.to_sym
        self.settings_definitions = settings_definitions.merge name => definition
      end

      # A block without any setting shows no settings form, a subclass may
      # bring one (settings_form!)
      def no_settings!
        self.without_settings = true
      end

      def settings_form!
        self.without_settings = false
      end

      def no_settings?
        without_settings
      end

      # The settings form is built from the declared settings instead of a
      # form of the block
      def generate_settings_form!
        self.generated_settings_form = true
      end

      def generated_settings_form?
        generated_settings_form
      end

      # Whether the block offers its data to programs, see export_data
      def exports_data?
        instance_method(:export_data).owner != Base
      end

      def settings_partial(name = nil)
        name ? self.settings_partial_value = name : settings_partial_value
      end

      # Called with the settings and the dashboard on save, returns the
      # settings to keep
      def settings_filter(callable = nil)
        callable ? self.settings_filter_value = callable : settings_filter_value
      end

      private

      # A setting may be declared again by a subclass, it must not hide
      # another method of the block
      def define_setting_reader(name, reader)
        if !settings_definitions.key?(name) && (method_defined?(reader) || private_method_defined?(reader))
          raise ArgumentError, "#{self}: setting #{name} would replace the method #{reader} of the block, name its reader"
        end

        self.setting_readers = setting_readers | [reader]
        define_method(reader) { settings_schema[name] }
      end
    end

    abstract!

    attr_reader :dashboard_content

    delegate :project, :user, to: :dashboard_content
    delegate :block_id, :label, :permission, :max_occurs, :partial, :settings_partial, :settings_filter,
             :no_settings?, :admin_only?, :generated_settings_form?, to: :class

    # settings: the stored settings of the block, for its typed values
    def initialize(dashboard_content, settings: {}, dashboard: nil)
      @dashboard_content = dashboard_content
      @stored_settings = settings.to_h.symbolize_keys
      @dashboard = dashboard
    end

    # Whether the block can be added, besides its permission, e.g. only with
    # an active module
    def available?
      true
    end

    # Whether the user may use the block here: its permissions (all of them),
    # admin only and its availability
    def allowed?
      return false if admin_only? && !user.admin?
      return false if permission && !Array(permission).all? { |name| user.allowed_to? name, project, global: true }

      available?
    end

    # Whether the user may compute the block with settings of their own,
    # without a dashboard (blocks API, AI tools). A block that reaches out
    # with its settings beyond the permissions of the user, e.g. to the URL
    # of a feed, keeps this to those who could set them on a dashboard.
    def own_settings_allowed?
      true
    end

    # Values a cached block loaded after the page depends on, nil for none
    def unique_params
      nil
    end

    # Options of a block loaded after the page (render_async), nil for a block
    # rendered with the page
    def async
      options = self.class.async
      return if options.nil?

      options = options.merge data_check_class: options[:data_check_class].constantize if options[:data_check_class].is_a? String
      params = unique_params
      params.nil? ? options : options.merge(unique_params: params)
    end

    # The data of the block for its settings, independent of the output: the
    # partial renders it, export_data turns it into plain values. Nil for a
    # block without data of its own.
    def data
      nil
    end

    # The data as plain values (strings, numbers, booleans, arrays and hashes)
    # for the API and AI or MCP tools, nil if the block offers none. A block
    # decides itself whether its data leaves the dashboard.
    def export_data
      nil
    end

    # What a program reads about the block: its label, typed settings and data.
    # Without data, the data is not loaded, e.g. for the layout of a dashboard.
    def export(data: true)
      export = { label:,
                 settings: settings_schema.available_keys.index_with { |key| export_value settings_schema[key] } }
      data ? export.merge(data: export_data) : export
    end

    # The declared settings with the rules the block answers with methods
    def declared_settings
      Additionals::SettingsSchema.with_rule_methods settings_definitions, self, except: setting_readers
    end

    # Whether the block declares the setting as required, e.g. to mark it in a
    # settings form several blocks share
    def setting_required?(key)
      declared_settings.dig(key.to_sym, :required) ? true : false
    end

    # The stored settings, read typed and with their defaults
    def settings_schema
      @settings_schema ||= Additionals::SettingsSchema.new declared_settings, {},
                                                           stored: @stored_settings, user:, project:, dashboard: @dashboard
    end

    private

    # What a chart of its own evaluation draws (AdditionalsChart#payload), for
    # programs: a column per dataset, a row per label with a value of each.
    # Nil for a chart without values.
    def export_chart(chart)
      return unless chart.valid?

      payload = chart.payload
      datasets = payload[:datasets]
      { measure: payload[:totalLabel],
        columns: datasets.pluck(:label),
        rows: payload[:labels].each_with_index.map do |label, index|
          [export_value(label), *datasets.map { |dataset| export_number dataset[:data][index] }]
        end }
    end

    # Sums of hours or amounts are decimals, which JSON would turn into strings
    def export_number(value)
      value.nil? || value.is_a?(Integer) ? value : value.to_f.round(2)
    end

    # A value for a program: dates as ISO 8601, records by their name
    def export_value(value)
      case value
      when nil, String, Numeric, true, false then value
      when Array then value.map { |entry| export_value entry }
      when Hash then value.transform_values { |entry| export_value entry }
      when Date, Time, ActiveSupport::TimeWithZone then value.iso8601
      # As the field shows it, e.g. a user by name instead of the stored id
      when CustomValue then export_value value.custom_field.format.formatted_custom_value(nil, value, false)
      else value.to_s
      end
    end
  end
end
