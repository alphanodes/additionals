# frozen_string_literal: true

require 'open-uri'

class DashboardAsyncBlocksController < ApplicationController
  before_action :find_dashboard
  before_action :find_block

  helper :additionals_routes
  helper :additionals_queries
  helper :additionals_settings
  helper :queries
  helper :issues
  helper :activities
  helper :dashboards

  include DashboardsHelper

  # support for redmine_contacts_helpdesk plugin
  if AdditionalsPlugin.active_contacts_helpdesk?
    include HelpdeskHelper

    helper :helpdesk
  end

  rescue_from StandardError, with: :dashboard_with_invalid_block

  def show
    @settings[:sort] = params[:sort] if params[:sort].present?
    partial_locals = build_dashboard_partial_locals @block, @settings, @dashboard

    respond_to do |format|
      format.html do
        render partial: partial_locals[:async][:partial],
               locals: partial_locals
      end
    end
  end

  # abuse create for query list sort order support
  def create
    return render_403 if params[:sort].blank?

    partial_locals = build_dashboard_partial_locals @block, @settings, @dashboard
    partial_locals[:sort_options] = { sort: params[:sort] }

    respond_to do |format|
      format.js do
        render partial: 'update_order_by',
               locals: partial_locals
      end
    end
  end

  private

  def find_dashboard
    @dashboard = Dashboard.find params[:dashboard_id]
    # Not raised: rescue_from StandardError would answer it as a block error
    return deny_access unless @dashboard.visible?

    if @dashboard.dashboard_type == DashboardContentProject::TYPE_NAME && @dashboard.project.nil?
      @dashboard.content_project = find_project_by_project_id
    else
      @project = @dashboard.project
      deny_access if @project.present? && !User.current.allowed_to?(:view_project, @project)
      @dashboard.content_project = @project
    end

    @can_edit = @dashboard&.editable?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_block
    @block = params['block']
    return render_404 if @block.blank?
    return render_403 unless @dashboard.content.find_block @block

    @settings = @dashboard.layout_settings @block
  end

  def exception_chain(exception)
    chain = []
    while exception && chain.exclude?(exception)
      chain << exception
      exception = exception.cause
    end
    chain
  end

  def block_heading
    return if @dashboard.nil? || @block.blank?

    @settings&.dig(:title).presence || @dashboard.content.dashboard_block(@block, dashboard: @dashboard)&.label
  rescue StandardError
    nil
  end

  def find_project_by_project_id
    begin
      @project = Project.find params[:project_id]
    rescue ActiveRecord::RecordNotFound
      render_404
    end
    deny_access unless User.current.allowed_to? :view_project, @project

    @project
  end

  # The error takes the place of the block content, below its heading like
  # the content. A failing query (also raised while rendering the partial) is
  # named as such, e.g. with a filter of a plugin that is not installed.
  def dashboard_with_invalid_block(exception)
    Rails.logger.error "Invalid dashboard block for #{@block} (#{exception.class.name}): #{exception.message}"
    @query_invalid = exception_chain(exception).any?(ActiveRecord::StatementInvalid)
    @block_heading = block_heading
    respond_to do |format|
      format.html do
        render template: 'dashboards/block_error', layout: false
      end
      format.any { head @status }
    end
  end
end
