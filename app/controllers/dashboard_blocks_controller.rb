# frozen_string_literal: true

# Dashboard blocks for programs, independent of a dashboard: which blocks the
# user can use in a context with their described settings (index), and one
# block computed with the settings of the request (show). Settings are those
# the caller sends, stored settings of dashboards never leave the server.
# JSON only, the data of a block is no fixed structure.
class DashboardBlocksController < ApplicationController
  before_action :find_dashboard_project
  before_action :build_dashboard

  accept_api_auth :index, :show

  def index
    blocks = @dashboard.content.available_block_schemas(dashboard: @dashboard).map do |id, schema|
      { id:, **schema }
    end

    render json: { dashboard_type: @dashboard.dashboard_type, project_id: @project&.id, dashboard_blocks: blocks }
  end

  def show
    block = params[:id].to_s
    return render_404 unless @dashboard.content.available_blocks.key? block

    settings = @dashboard.permitted_block_settings block, settings_params
    schema = @dashboard.content.block_settings block, values: settings, dashboard: @dashboard
    return render_api_errors schema.full_messages if schema && !schema.valid?

    export = @dashboard.content.dashboard_block(block, settings: schema ? schema.settings : settings, dashboard: @dashboard).export
    render json: { dashboard_block: { id: block, **export } }
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

  # A dashboard of the context that is never saved: blocks check their
  # permissions and rules against it like on a real one
  def build_dashboard
    type = params[:dashboard_type].presence ||
           (@project ? DashboardContentProject::TYPE_NAME : DashboardContentWelcome::TYPE_NAME)
    error = dashboard_type_error type
    return render_api_errors error if error

    @dashboard = Dashboard.new dashboard_type: type, author: User.current, project: @project, content_project: @project
  end

  def dashboard_type_error(type)
    if DashboardContent.types.exclude? type
      "#{Dashboard.human_attribute_name :dashboard_type} #{l 'activerecord.errors.messages.inclusion'}"
    elsif type == DashboardContentProject::TYPE_NAME && @project.nil?
      "#{l :field_project} #{l 'activerecord.errors.messages.blank'}"
    end
  end

  def settings_params
    params[:settings].respond_to?(:to_unsafe_h) ? params[:settings].to_unsafe_h : {}
  end
end
