# frozen_string_literal: true

require 'open-uri'

class DashboardAsyncBlocksController < ApplicationController
  before_action :find_dashboard
  before_action :find_block

  helper :additionals_routes
  helper :additionals_queries
  helper :queries
  helper :issues
  helper :activities
  helper :dashboards

  include DashboardsHelper

  # support for redmine_contacts_helpdesk plugin
  if Redmine::Plugin.installed? 'redmine_contacts_helpdesk'
    include HelpdeskHelper
    helper :helpdesk
  end

  rescue_from Query::StatementInvalid, with: :query_statement_invalid
  rescue_from StandardError, with: :dashboard_with_invalid_block

  def show
    @settings[:sort] = params[:sort] if params[:sort].present?
    partial_locals = build_dashboard_partial_locals @block, @block_definition, @settings, @dashboard

    respond_to do |format|
      format.js do
        render partial: partial_locals[:async][:partial],
               content_type: 'text/html',
               locals: partial_locals
      end
    end
  end

  # abuse create for query list sort order support
  def create
    return render_403 if params[:sort].blank?

    partial_locals = build_dashboard_partial_locals @block, @block_definition, @settings, @dashboard
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
    raise ::Unauthorized unless @dashboard.visible?

    if @dashboard.dashboard_type == DashboardContentProject::TYPE_NAME && @dashboard.project.nil?
      @dashboard.content_project = find_project_by_project_id
    else
      @project = @dashboard.project
      deny_access if @project.present? && !User.current.allowed_to?(:view_project, @project)
    end

    @can_edit = @dashboard&.editable?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_block
    @block = params['block']
    @block_definition = @dashboard.content.find_block @block

    render_404 if @block.blank?
    render_403 if @block_definition.blank?

    @settings = @dashboard.layout_settings @block
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

  def dashboard_with_invalid_block(exception)
    logger&.error "Invalid dashboard block for #{@block} (#{exception.class.name}): #{exception.message}"
    respond_to do |format|
      format.html do
        render template: 'dashboards/block_error', layout: false
      end
      format.any { head @status }
    end
  end
end
