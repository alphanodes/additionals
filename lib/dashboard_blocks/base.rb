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
  # Settings use the format of Additionals::SettingsSchema. What depends on the
  # user, the project or the data is an instance method (available?,
  # unique_params), the rest is declared on the class and inherited.
  class Base
    class_attribute :settings_definitions, instance_writer: false, default: {}
    class_attribute :declared_dashboard_types, instance_writer: false
    class_attribute :max_occurs_count, instance_writer: false, default: 1
    class_attribute :block_id_value, :label_value, :permission_value, :partial_value, :async_options,
                    :settings_partial_value, :settings_filter_value, instance_writer: false
    class_attribute :without_settings, :admin_only_value, instance_writer: false, default: false
    # Keys of a definition no declaration covers (yet)
    class_attribute :extra_definition, instance_writer: false, default: {}

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

      def setting(name, **definition)
        self.settings_definitions = settings_definitions.merge name.to_sym => definition
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

      def settings_partial(name = nil)
        name ? self.settings_partial_value = name : settings_partial_value
      end

      # Called with the settings and the dashboard on save, returns the
      # settings to keep
      def settings_filter(callable = nil)
        callable ? self.settings_filter_value = callable : settings_filter_value
      end

      def definition(**options)
        self.extra_definition = extra_definition.merge options
      end
    end

    abstract!

    attr_reader :dashboard_content

    delegate :project, :user, to: :dashboard_content
    delegate :block_id, :label, to: :class

    def initialize(dashboard_content)
      @dashboard_content = dashboard_content
    end

    # Whether the block can be added, besides its permission, e.g. only with
    # an active module
    def available?
      true
    end

    # Values a cached block loaded after the page depends on, nil for none
    def unique_params
      nil
    end

    # The block as entry of DashboardContent#block_definitions
    def to_definition
      definition = { label:, if: ->(_project) { available? } }
      definition[:permission] = self.class.permission if self.class.permission
      definition[:admin_only] = true if self.class.admin_only?
      definition[:max_occurs] = self.class.max_occurs if self.class.max_occurs != 1
      definition[:partial] = self.class.partial if self.class.partial
      definition[:async] = async_definition if self.class.async
      definition[:no_settings] = true if self.class.no_settings?
      definition[:settings] = self.class.settings_definitions if self.class.settings_definitions.any?
      definition[:settings_partial] = self.class.settings_partial if self.class.settings_partial
      definition[:settings_filter] = self.class.settings_filter if self.class.settings_filter
      definition.merge self.class.extra_definition
    end

    private

    def async_definition
      params = unique_params
      params.nil? ? self.class.async : self.class.async.merge(unique_params: params)
    end
  end
end
