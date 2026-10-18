# frozen_string_literal: true

# Dashboard blocks for programs, independent of a dashboard: which blocks the
# user can use, with their described settings (index), and one block computed
# with the settings of the request (show). Settings are those the caller
# sends, stored settings of dashboards never leave the server. JSON only, the
# data of a block is no fixed structure.
#
# Without a project the blocks are those of the welcome page and those only
# other dashboard types offer (e.g. HRM), if the user may use that type
# (DashboardContent.blocks_accessible?). A block of several types counts once,
# with the first type offering it: its own rules decide there.
class DashboardBlocksController < ApplicationController
  before_action :find_dashboard_project

  accept_api_auth :index, :show

  def index
    blocks = dashboards.flat_map do |dashboard|
      dashboard.content.available_block_schemas(dashboard:).map { |id, schema| { id:, **schema } }
    end
    blocks.uniq! { |block| block[:id] }

    render json: { project_id: @project&.id, dashboard_blocks: blocks }
  end

  def show
    block = params[:id].to_s
    dashboard = dashboards.detect { |entry| entry.content.available_blocks.key? block }
    return render_404 unless dashboard

    settings = dashboard.permitted_block_settings block, settings_params
    schema = dashboard.content.block_settings block, values: settings, dashboard: dashboard
    errors = settings_errors schema
    return render_api_errors errors if errors.any?

    export = dashboard.content.dashboard_block(block, settings: schema ? schema.settings : settings, dashboard:).export
    render json: { dashboard_block: { id: block, **export, settings_not_applied: schema&.not_applied_keys || [] } }
  end

  private

  # By id or identifier; a project the user cannot see is not found
  def find_dashboard_project
    return if params[:project_id].blank?

    @project = Project.find params[:project_id]
    render_404 unless @project.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Dashboards that are never saved, one per dashboard type of the context in
  # the order a block counts with: blocks check their permissions and rules
  # against them like on a real one
  def dashboards
    @dashboards ||= dashboard_types.map do |type|
      Dashboard.new dashboard_type: type::TYPE_NAME, author: User.current, project: @project, content_project: @project
    end
  end

  def dashboard_types
    return [DashboardContentProject] if @project

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

  # Invalid values, and settings the block does not have here: a program
  # learns of a typo or a setting of another context instead of a result
  # without it. Unlike saving on a dashboard, which drops unknown settings.
  def settings_errors(schema)
    return [] if schema.nil?

    invalid = l 'activerecord.errors.messages.invalid'
    schema.ignored_keys.map { |key| "#{key} #{invalid}" } + schema.full_messages
  end

  def settings_params
    params[:settings].respond_to?(:to_unsafe_h) ? params[:settings].to_unsafe_h : {}
  end
end
