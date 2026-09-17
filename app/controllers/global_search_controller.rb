# frozen_string_literal: true

class GlobalSearchController < ApplicationController
  before_action :require_login
  before_action :find_optional_search_project

  def search
    query = search_query

    if query.length < 2
      render json: initial_data
      return
    end

    results = GlobalSearch.search query,
                                  user: User.current,
                                  project: @search_project,
                                  scope: params[:scope],
                                  types: params[:types],
                                  titles_only: params[:titles_only].present?,
                                  limit: params[:limit]&.to_i || 10

    render json: results
  rescue StandardError => e
    render_search_error e
  end

  # Results of the registered providers (semantic search). keyword_hits tells whether the
  # keyword search found anything, which decides whether a bare number is worth asking for.
  def semantic
    query = search_query
    results = if query.length >= 2
                GlobalSearch.provider_search query,
                                             user: User.current,
                                             project: @search_project,
                                             types: params[:types],
                                             keyword_hits: params[:keyword_hits].to_i.positive?
              end

    render json: results || { label: nil, results: [] }
  rescue StandardError => e
    render_search_error e
  end

  private

  def search_query
    params[:q].to_s.strip
  end

  def find_optional_search_project
    @search_project = Project.visible.find_by identifier: params[:project_id] if params[:project_id].present?
  end

  def render_search_error(error)
    Rails.logger.error "GlobalSearch error: #{error.message}\n#{error.backtrace&.first(5)&.join "\n"}"
    render json: { error: error.message }, status: :internal_server_error
  end

  def initial_data
    jump_box = Redmine::ProjectJumpBox.new User.current

    projects = jump_box.recently_used_projects.map do |project|
      { id: project.id,
        title: project.name,
        url: project_path(project),
        type: l(:label_project) }
    end

    { keyword: projects, jump: false }
  end
end
