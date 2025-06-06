# frozen_string_literal: true

class DashboardsController < ApplicationController
  menu_item :dashboards

  before_action :find_dashboard, except: %i[index new create]
  before_action :find_optional_project, only: %i[index new create]

  accept_api_auth :index, :show, :create, :update, :destroy

  helper :queries
  helper :issues
  helper :activities
  helper :watchers
  helper :additionals_routes
  helper :dashboards
  helper :additionals_issues
  helper :additionals_queries
  helper :additionals_settings

  include AdditionalsRoutesHelper
  include AdditionalsQueriesHelper
  include QueriesHelper
  include WatchersHelper
  include SortHelper

  def index
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit = per_page_option
    end

    scope = Dashboard.visible
    @query_count = scope.count
    @query_pages = Paginator.new @query_count, @limit, params['page']
    @dashboards = scope.sorted
                       .limit(@limit)
                       .offset(@offset)
                       .to_a

    respond_to do |format|
      format.html { render_error status: 406 }
      format.api
    end
  end

  def show
    respond_to do |format|
      format.html { head :not_acceptable }
      format.js if request.xhr?
      format.api
    end
  end

  def new
    @dashboard = Dashboard.new project: @project,
                               author: User.current
    @dashboard.dashboard_type = assign_dashboard_type
    @allowed_projects = @dashboard.allowed_target_projects
  end

  def edit
    return render_403 unless @dashboard.editable?

    @allowed_projects = @dashboard.allowed_target_projects

    respond_to do |format|
      format.html
      format.api
    end
  end

  def create
    @dashboard = Dashboard.new author: User.current
    @dashboard.safe_attributes = params[:dashboard]
    @dashboard.dashboard_type = assign_dashboard_type
    @dashboard.role_ids = params[:dashboard][:role_ids] if params[:dashboard].present?

    @allowed_projects = @dashboard.allowed_target_projects

    if @dashboard.save
      respond_to do |format|
        format.html do
          flash[:notice] = flash_msg :create
          redirect_to dashboard_link_path(@project, @dashboard)
        end
        format.api  { render action: :show, status: :created, location: dashboard_url(@dashboard, project_id: @project) }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.api  { render_validation_errors @dashboard }
      end
    end
  end

  def update
    return render_403 unless @dashboard.editable?

    # should be set before dashboard object has modified
    @allowed_projects = @dashboard.allowed_target_projects

    @dashboard.safe_attributes = params[:dashboard]
    @dashboard.role_ids = params[:dashboard][:role_ids] if params[:dashboard].present?

    @project = @dashboard.project if @project && @dashboard.project_id.present? && @dashboard.project != @project

    if @dashboard.save
      flash[:notice] = flash_msg :update
      respond_to do |format|
        format.html { redirect_to dashboard_link_path(@project, @dashboard) }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.api  { render_validation_errors @dashboard }
      end
    end
  end

  def destroy
    return render_403 unless @dashboard.deletable?

    begin
      @dashboard.destroy
      flash[:notice] = flash_msg :delete
      respond_to do |format|
        format.html { redirect_to @project.nil? ? home_path : project_path(@project) }
        format.api  { render_api_ok }
      end
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = flash_msg :delete_error, obj: @dashboard
      redirect_to dashboard_path(@dashboard)
    end
  end

  def update_layout_setting
    block_settings = params[:settings] || {}

    block_settings.each do |block, settings|
      @dashboard.update_block_settings block, settings.to_unsafe_hash
    end
    @dashboard.save
    @updated_blocks = block_settings.keys
  end

  # The block is added on top of the page
  # params[:block] : id of the block to add
  def add_block
    @block = params[:block]
    if @dashboard.add_block @block
      @dashboard.save
      respond_to do |format|
        format.html { redirect_to dashboard_link_path(@project, @dashboard) }
        format.js
      end
    else
      render_error status: 422
    end
  end

  # params[:block] : id of the block to remove
  def remove_block
    @block = params[:block]
    @dashboard.remove_block @block
    @dashboard.save
    respond_to do |format|
      format.html { redirect_to dashboard_link_path(@project, @dashboard) }
      format.js
    end
  end

  # Change blocks order
  # params[:group] : group to order (top, left or right)
  # params[:blocks] : array of block ids of the group
  def order_blocks
    @dashboard.order_blocks params[:group], params[:blocks]
    @dashboard.save
    head :ok
  end

  private

  def assign_dashboard_type
    if params['dashboard_type'].present?
      params['dashboard_type']
    elsif params['dashboard'].present? && params['dashboard']['dashboard_type'].present?
      params['dashboard']['dashboard_type']
    elsif @project.nil?
      DashboardContentWelcome::TYPE_NAME
    else
      DashboardContentProject::TYPE_NAME
    end
  end

  def find_dashboard
    @dashboard = Dashboard.find params[:id]
    raise ::Unauthorized unless @dashboard.visible?

    if @dashboard.dashboard_type == DashboardContentProject::TYPE_NAME && @dashboard.project.nil?
      @dashboard.content_project = if params[:dashboard].present? && params[:dashboard][:content_project_id].present?
                                     find_project params[:dashboard][:content_project_id]
                                   else
                                     find_project_by_project_id
                                   end
    else
      @project = @dashboard.project
    end

    @can_edit = @dashboard&.editable?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
