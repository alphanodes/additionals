# frozen_string_literal: true

module Additionals
  # Dashboard blocks for programs, independent of a dashboard, for the current
  # user: which blocks the user can use with their described settings, and one
  # block computed with given settings. Used by DashboardBlocksController (API) and
  # AI or MCP tools, so both answer the same.
  #
  # Without a project the blocks are those of the welcome page and those only
  # other dashboard types offer (e.g. HRM), if the user may use that type
  # (DashboardContent.blocks_accessible?). A block of several types counts once,
  # with the first type offering it: its own rules decide there. Settings are
  # those the caller gives, stored settings of dashboards never leave the
  # server.
  #
  #   service = Additionals::DashboardBlockService.new project: @project
  #   service.blocks                          # => [{ id: 'news', label: ..., settings: [...] }, ...]
  #   result = service.block 'news', settings: { max_entries: '5' }
  #   result.status                           # => :ok, :not_found or :invalid
  #   result.block                            # => { id:, label:, settings:, settings_not_applied:, data: }
  #   result.errors                           # => ['max_entry is invalid', ...]
  class DashboardBlockService
    include Redmine::I18n

    Result = Data.define :status, :block, :errors do
      def ok? = status == :ok
    end

    attr_reader :project

    # project: a project the user can see, nil for blocks without a project
    def initialize(project: nil)
      @project = project
    end

    def blocks
      list = dashboards.flat_map do |dashboard|
        dashboard.content.available_block_schemas(dashboard:).map { |id, schema| { id:, **schema } }
      end
      list.uniq { |block| block[:id] }
    end

    # Invalid values, and settings the block does not have here, are errors: a
    # program learns of a typo instead of a result without it. Unlike saving on
    # a dashboard, which drops unknown settings.
    def block(id, settings: {})
      id = id.to_s
      dashboard = dashboards.detect { |entry| entry.content.available_blocks.key? id }
      return Result.new status: :not_found, block: nil, errors: [] unless dashboard

      settings = dashboard.permitted_block_settings id, settings.to_h
      schema = dashboard.content.block_settings id, values: settings, dashboard: dashboard
      errors = settings_errors schema
      return Result.new(status: :invalid, block: nil, errors:) if errors.any?

      export = dashboard.content.dashboard_block(id, settings: schema ? schema.settings : settings, dashboard:).export
      Result.new status: :ok, errors: [],
                 block: { id:, **export, settings_not_applied: schema&.not_applied_keys || [] }
    end

    private

    # Dashboards that are never saved, one per dashboard type of the context in
    # the order a block counts with: blocks check their permissions and rules
    # against them like on a real one
    def dashboards
      @dashboards ||= dashboard_types.map do |type|
        Dashboard.new dashboard_type: type::TYPE_NAME, author: User.current, project:, content_project: project
      end
    end

    def dashboard_types
      return [DashboardContentProject] if project

      [DashboardContentWelcome] + other_dashboard_types.select { |type| type.blocks_accessible? User.current }
    end

    # Types named by the blocks (dashboards), as dashboard contents may load lazily
    def other_dashboard_types
      names = DashboardBlocks.all.flat_map { |block| block.declared_dashboard_types || [] }.to_set - %i[welcome project]
      names.filter_map do |name|
        type = "DashboardContent#{name.to_s.camelize}".safe_constantize
        type if type.is_a?(Class) && type < DashboardContent
      end
    end

    def settings_errors(schema)
      return [] if schema.nil?

      invalid = l 'activerecord.errors.messages.invalid'
      schema.ignored_keys.map { |key| "#{key} #{invalid}" } + schema.full_messages
    end
  end
end
