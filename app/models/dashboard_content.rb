# frozen_string_literal: true

class DashboardContent
  include Redmine::I18n

  attr_accessor :project

  MAX_MULTIPLE_OCCURS = 8
  DEFAULT_MAX_ENTRIES = 10
  RENDER_ASYNC_CACHE_EXPIRES_IN = 30

  # Groups spanning the full width as their own row (as opposed to the 50%
  # left/right columns). Empty ones may be skipped in read-only layouts.
  FULL_WIDTH_GROUPS = %w[top bottom].freeze

  # Settings many blocks share, see Additionals::SettingsSchema
  TITLE_SETTING = { type: :string, label: :field_title }.freeze
  MAX_ENTRIES_SETTING = { type: :integer, label: :label_max_entries, min: 1, max: 100, required: true,
                          default: DEFAULT_MAX_ENTRIES }.freeze

  class << self
    def types
      descendants.map { |dc| dc::TYPE_NAME }
    end

    # Whether the user may use dashboards and blocks of this type, e.g. a type
    # with a page of its own that is restricted: Dashboard#visible? asks it, and
    # the blocks API for blocks only this type offers
    def blocks_accessible?(_user)
      true
    end

    # Saved queries a block of the project can show, exactly of this class
    # (not e.g. a subclass of another plugin)
    def selectable_queries(klass, project)
      klass.visible
           .global_or_on_project(project)
           .where(type: klass.to_s)
           .sorted
    end
  end

  def initialize(attr = {})
    self.project = attr[:project].presence
  end

  def groups
    %w[top left right bottom]
  end

  def full_width_group?(group)
    FULL_WIDTH_GROUPS.include? group.to_s
  end

  # The 50% column groups (left/right) as opposed to the full-width rows.
  def column_groups
    groups - FULL_WIDTH_GROUPS
  end

  # The blocks this content offers by id, from the block classes of all
  # plugins (DashboardBlocks), whether or not the user may use them
  def blocks
    @blocks ||= DashboardBlocks.for(self).index_by(&:block_id)
  end

  # Type of the dashboard blocks name in DashboardBlocks::Base.dashboards,
  # e.g. :welcome for DashboardContentWelcome, nil for this base class
  def dashboard_type
    self.class.name.delete_prefix('DashboardContent').underscore.presence&.to_sym
  end

  # The blocks the user can use here by id, sorted by their label
  def available_blocks
    @available_blocks ||= blocks.select { |_id, block| block.allowed? }.sort_by { |_id, block| block.label }.to_h
  end

  def block_options(blocks_in_use = [])
    available_blocks.map do |name, block|
      indexes = blocks_in_use.filter_map do |n|
        Regexp.last_match(2).to_i if n =~ /\A#{name}(__(\d+))?\z/
      end

      block_id = indexes.any? ? "#{name}__#{indexes.max + 1}" : name
      block_id = nil if indexes.size >= block.max_occurs
      [block.label, block_id]
    end
  end

  def valid_block?(block, blocks_in_use = [])
    block.present? && block_options(blocks_in_use).map(&:last).include?(block)
  end

  # The block of a block id (e.g. feed__2) if the user can use it here
  def find_block(block)
    available_blocks[block_name(block)]
  end

  # Name of the block of a block id, e.g. feed for feed__2
  def block_name(block)
    block.to_s.sub(/__\d+\z/, '')
  end

  # Settings a block declares, nil if it declares none: such a block keeps
  # every setting it gets.
  def block_settings_definitions(block)
    settings_definitions_of blocks[block_name(block)]
  end

  # Settings of a block with the given values, completed by its stored ones,
  # see Additionals::SettingsSchema. Nil for blocks without declared settings.
  def block_settings(block, values: {}, stored: {}, dashboard: nil)
    settings_schema settings_definitions_of(blocks[block_name(block)]), values, dashboard, stored:
  end

  # The blocks the user can add, with their settings and whether they export
  # their data, for programmatic clients
  def available_block_schemas(dashboard: nil)
    available_blocks.transform_values do |block|
      { label: block.label,
        max_occurs: block.max_occurs,
        exports_data: block.class.exports_data?,
        settings: settings_schema(settings_definitions_of(block), {}, dashboard)&.describe }
    end
  end

  # The block of a block id with its stored settings, nil for a block this
  # content does not offer
  def dashboard_block(block, settings: {}, dashboard: nil)
    blocks[block_name(block)]&.class&.new self, settings:, dashboard:
  end

  # Returns the default layout for a new dashboard
  def default_layout
    {
      'left' => ['legacy_left'],
      'right' => ['legacy_right']
    }
  end

  # How long blocks about the issues of the user may be cached, longer with more
  # open issues
  def issues_cache_expires_in
    open_issue_count = Rails.cache.fetch issues_cache_key, expires_in: 1.hour do
      query = if project
                IssueQuery.new project:, name: '_'
              else
                IssueQuery.new name: '_'
              end
      query.issue_count
    end

    if open_issue_count > 1_000
      86_400 # 1 day
    elsif open_issue_count > 500
      14_400 # 4 hour
    elsif open_issue_count > 200
      3_600 # 1 hour
    elsif open_issue_count > 100
      1_800 # 30 minutes
    else
      60
    end
  end

  private

  def settings_definitions_of(block)
    return if block.nil?
    return {} if block.no_settings?

    block.declared_settings if block.settings_definitions.any?
  end

  def settings_schema(definitions, values, dashboard, stored: {})
    return if definitions.nil?

    Additionals::SettingsSchema.new definitions, values, stored:, project:, dashboard:
  end

  def issues_cache_key
    Digest::SHA256.hexdigest [project&.id, User.current.id].compact.join('-')
  end
end
