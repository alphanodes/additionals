# frozen_string_literal: true

# The dashboard blocks API (Additionals::DashboardBlockService): which blocks
# the user can use, and one block computed with the settings of the request.
# JSON only, the data of a block is no fixed structure.
class DashboardBlocksController < ApplicationController
  # Also where Redmine requires no login: blocks may compute a lot
  before_action :require_login
  before_action :find_dashboard_project

  accept_api_auth :index, :show

  def index
    render json: { project_id: @project&.id, dashboard_blocks: service.blocks }
  end

  def show
    settings = params[:settings]
    # Anything but an object of settings, e.g. a string, would read as none
    if settings.present? && !settings.respond_to?(:to_unsafe_h)
      return render_api_errors "settings #{l 'activerecord.errors.messages.invalid'}"
    end

    result = service.block params[:id], settings: settings_params
    case result.status
    when :not_found then render_404
    when :forbidden then render_403
    when :invalid then render_api_errors result.errors
    else render json: { dashboard_block: result.block }
    end
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

  def service
    @service ||= Additionals::DashboardBlockService.new project: @project
  end

  def settings_params
    params[:settings].respond_to?(:to_unsafe_h) ? params[:settings].to_unsafe_h : {}
  end
end
