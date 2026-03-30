# frozen_string_literal: true

class GlobalSearchController < ApplicationController
  before_action :require_login

  def search
    query = params[:q].to_s.strip
    project = Project.visible.find_by identifier: params[:project_id] if params[:project_id].present?

    if query.length < 2
      render json: initial_data
      return
    end

    results = GlobalSearch.search query,
                                  user: User.current,
                                  project: project,
                                  limit: params[:limit]&.to_i || 10

    render json: results
  end

  private

  def initial_data
    jump_box = Redmine::ProjectJumpBox.new User.current

    projects = jump_box.recently_used_projects.map do |project|
      { id: project.id,
        title: project.name,
        url: project_path(project),
        type: l(:label_project) }
    end

    { keyword: projects, semantic: nil }
  end
end
