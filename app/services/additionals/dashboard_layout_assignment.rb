# frozen_string_literal: true

module Additionals
  # Assigns the complete layout of a dashboard, see Dashboard#assign_layout.
  # Errors are keyed by block id with the messages per setting (:base for the
  # block itself), and by :base for the dashboard and its groups. Ignored are
  # the keys of given settings a block does not know.
  class DashboardLayoutAssignment
    BLOCK_ID_FORMAT = /\A[a-z0-9_]+?(__\d+)?\z/

    Result = Data.define :errors, :ignored do
      def success?
        errors.empty?
      end
    end

    def initialize(dashboard, spec)
      @dashboard = dashboard
      @content = dashboard.content
      @errors = {}
      @ignored = {}
      @spec = hash_of(spec)&.transform_keys(&:to_s)
      add_base_error l('activerecord.errors.messages.invalid') if @spec.nil?
    end

    def call
      return result unless @errors.empty?

      unless @dashboard.layout_editable?
        message = @dashboard.locked? ? l(:label_dashboard_lock_is_active) : l(:notice_not_authorized)
        return Result.new errors: { base: [message] }, ignored: {}
      end

      layout, settings = build
      if @errors.empty?
        @dashboard.layout = layout
        @dashboard.layout_settings = settings
      end
      result
    end

    private

    def result
      Result.new errors: @errors, ignored: @ignored
    end

    # A program may send parameters or anything else instead of a hash
    def hash_of(value)
      value = value.to_unsafe_h if value.respond_to? :to_unsafe_h
      value.to_h.symbolize_keys if value.is_a? Hash
    end

    def l(...)
      ::I18n.t(...)
    end

    def build
      check_groups
      entries = @spec.flat_map { |group, blocks| group_blocks(group, blocks).map { |entry| [group, normalize(entry)] } }
      check_blocks(entries.map { |_group, entry| entry[:block] })

      layout = @content.groups.index_with { [] }
      settings = {}
      entries.each do |group, entry|
        block = entry[:block]
        layout[group] << block if layout.key? group
        block_settings = settings_for block, entry
        settings[block] = block_settings if block_settings.present?
      end
      [layout, settings]
    end

    def group_blocks(group, blocks)
      return blocks if blocks.is_a? Array

      add_base_error "#{group} #{l 'activerecord.errors.messages.invalid'}"
      []
    end

    def normalize(entry)
      entry_hash = hash_of entry
      return { block: entry.to_s } if entry_hash.nil?

      entry_hash.merge block: entry_hash[:block].to_s
    end

    def check_groups
      (@spec.keys - @content.groups).each do |group|
        add_base_error "#{group} #{l 'activerecord.errors.messages.inclusion'}"
      end
    end

    def check_blocks(blocks)
      occurs = Hash.new 0
      blocks.each_with_index do |block, index|
        if blocks.index(block) != index
          add_error block, l('activerecord.errors.messages.taken')
          next
        end

        definition = @content.find_block block if block.match? BLOCK_ID_FORMAT
        if definition.nil?
          add_error block, l('activerecord.errors.messages.inclusion')
          next
        end

        name = definition[:name]
        occurs[name] += 1
        max_occurs = definition[:max_occurs] || 1
        add_error block, l('activerecord.errors.messages.less_than_or_equal_to', count: max_occurs) if occurs[name] > max_occurs
      end
    end

    # Stored settings of a block without settings, the given ones otherwise
    def settings_for(block, entry)
      return @dashboard.layout_settings[block] unless entry.key? :settings

      settings = entry[:settings].nil? ? {} : hash_of(entry[:settings])
      if settings.nil?
        add_error block, l('activerecord.errors.messages.invalid')
        return
      end

      settings = @dashboard.permitted_block_settings block, settings
      schema = @content.block_settings block, values: settings, dashboard: @dashboard
      return settings if schema.nil?

      @ignored[block] = schema.ignored_keys if schema.ignored_keys.any?
      (@errors[block] ||= {}).merge! schema.errors unless schema.valid?
      schema.settings
    end

    def add_base_error(message)
      (@errors[:base] ||= []) << message
    end

    def add_error(block, message)
      ((@errors[block] ||= {})[:base] ||= []) << message
    end
  end
end
