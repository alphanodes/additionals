# frozen_string_literal: true

module Additionals
  # Assigns the complete layout of a dashboard, see Dashboard#assign_layout.
  # Errors are keyed by block id with the messages per setting (:base for the
  # block itself), and by :base for the dashboard and its groups. Ignored are
  # the keys of given settings a block does not know.
  #
  # Stored blocks the user cannot use here (another project, a missing
  # permission) stay with their settings where they are: a program does not
  # see them and would remove them for everyone. Given back, they may move,
  # but their settings cannot change here.
  class DashboardLayoutAssignment
    BLOCK_ID_FORMAT = /\A[a-z0-9_]+?(__\d+)?\z/

    Result = Data.define :errors, :ignored do
      def success?
        errors.empty?
      end
    end

    def initialize(dashboard, spec, keep_settings: false)
      @dashboard = dashboard
      @keep_settings = keep_settings
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
      given = entries.map { |_group, entry| entry[:block] }
      check_blocks given

      layout = @content.groups.index_with { [] }
      settings = {}
      entries.each do |group, entry|
        block = entry[:block]
        layout[group] << block if layout.key? group
        block_settings = settings_for block, entry
        settings[block] = block_settings if block_settings.present?
      end
      keep_unavailable_blocks layout, settings, given
      [layout, settings]
    end

    def unavailable_blocks
      @unavailable_blocks ||= @dashboard.layout.each_value.flat_map do |blocks|
        Array(blocks).reject { |block| @content.find_block block }
      end
    end

    # At their position in their group, as far as the group reaches
    def keep_unavailable_blocks(layout, settings, given)
      stored_settings = @dashboard.layout_settings
      @dashboard.layout.each do |group, blocks|
        next unless layout.key? group

        Array(blocks).each_with_index do |block, index|
          next if given.include?(block) || unavailable_blocks.exclude?(block)

          layout[group].insert [index, layout[group].size].min, block
          settings[block] = stored_settings[block] if stored_settings[block].present?
        end
      end
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

        next if unavailable_blocks.include? block

        dashboard_block = @content.find_block block if block.match? BLOCK_ID_FORMAT
        if dashboard_block.nil?
          add_error block, l('activerecord.errors.messages.inclusion')
          next
        end

        occurs[dashboard_block.block_id] += 1
        next if occurs[dashboard_block.block_id] <= dashboard_block.max_occurs

        add_error block, l('activerecord.errors.messages.less_than_or_equal_to', count: dashboard_block.max_occurs)
      end
    end

    # Stored settings of a block without settings, the given ones otherwise
    def settings_for(block, entry)
      return @dashboard.layout_settings[block] unless entry.key? :settings

      if unavailable_blocks.include? block
        add_error block, l('activerecord.errors.messages.inclusion')
        return @dashboard.layout_settings[block]
      end

      settings = entry[:settings].nil? ? {} : hash_of(entry[:settings])
      if settings.nil?
        add_error block, l('activerecord.errors.messages.invalid')
        return
      end

      settings = @dashboard.permitted_block_settings block, settings
      stored = @keep_settings ? @dashboard.layout_settings[block].to_h : {}
      schema = @content.block_settings block, values: settings, stored:, dashboard: @dashboard
      return stored.merge settings if schema.nil?

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
