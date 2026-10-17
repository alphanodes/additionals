# frozen_string_literal: true

module Additionals
  # Replaces blocks of all dashboards by others, e.g. in a migration when a
  # plugin moves its charts to the query chart blocks. For every block the
  # caller returns [[name, settings], ...] to replace it, or nil to keep it.
  # The new blocks take the place of the old one, numbered like
  # DashboardContent#block_options.
  class DashboardBlockReplacer
    class << self
      def call(&)
        Dashboard.find_each { |dashboard| replace_blocks dashboard, & }
      end

      # Custom field ids of an old chart block that still exist. Stored as
      # array from the form, as comma list after a rendering.
      def existing_custom_field_ids(value)
        ids = value.is_a?(Array) ? value : value.to_s.split(',')
        ids = ids.map { |id| id.to_s.strip }.compact_blank
        ids & CustomField.where(id: ids).pluck(:id).map(&:to_s)
      end

      # Settings of a query chart block showing a distribution like the old
      # field charts: pie with table of values and entries without value
      def chart_settings(group_by, open_only: nil, chart_type: 'pie', with_table: '1')
        settings = { group_by:, chart_type:, show_empty: '1', with_table: }
        settings[:open_only] = open_only.to_s if open_only.present?
        settings
      end

      # Old day matrix blocks become chart blocks shown as calendar, keeping
      # their query. replacements: { 'old_block' => ['new_block', 'date column', {other settings}] },
      # a block placed more than once (old_block__2) counts as old_block.
      def replace_with_calendars(replacements)
        call do |block, settings|
          target, group_by, extra = replacements[block.sub(/__\d+\z/, '')]
          next unless target

          [[target, { group_by:, chart_type: 'calendar', query_id: settings[:query_id].to_s }.merge(extra || {})]]
        end
      end

      private

      def replace_blocks(dashboard)
        options = dashboard.options
        return unless options.is_a?(Hash) && options[:layout].is_a?(Hash)

        layout_settings = options[:layout_settings] || {}
        used_ids = options[:layout].values.flatten
        changed = false

        options[:layout].each_value do |blocks|
          next unless blocks.is_a? Array

          blocks.map! do |block|
            replacements = yield block, layout_settings[block] || {}
            next block if replacements.nil?

            changed = true
            layout_settings.delete block
            replacements.map do |name, settings|
              block_id = next_block_id name, used_ids
              used_ids << block_id
              layout_settings[block_id] = settings
              block_id
            end
          end
          blocks.flatten!
        end
        return unless changed

        options[:layout_settings] = layout_settings
        dashboard.update_column :options, options
      end

      def next_block_id(name, used_ids)
        indexes = used_ids.filter_map do |id|
          Regexp.last_match(2).to_i if id =~ /\A#{name}(__(\d+))?\z/
        end
        indexes.any? ? "#{name}__#{indexes.max + 1}" : name
      end
    end
  end
end
