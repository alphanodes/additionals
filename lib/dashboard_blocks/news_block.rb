# frozen_string_literal: true

module DashboardBlocks
  class NewsBlock < Base
    block_id 'news'
    label :label_news_latest
    permission :view_news
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 1000
    setting :with_subprojects, type: :boolean, label: :label_cross_project_descendants

    def available?
      Redmine::AccessControl.active_module? :news
    end

    # The latest news of the project, with its subprojects if chosen
    def data
      @data ||= project.nil? ? News.latest(user, max_entries) : project_news
    end

    def export_data
      data.map do |news|
        { id: news.id, title: news.title, summary: news.summary.presence, project: news.project.name,
          author: news.author&.name, created_on: news.created_on.iso8601, comments_count: news.comments_count }
      end
    end

    private

    def project_news
      scope = with_subprojects && !project.leaf? ? News.visible(user).where(project_id: project.self_and_descendants.ids) : project.news
      scope.limit(max_entries).includes(:author, :project).reorder(created_on: :desc).to_a
    end

    # Subprojects only exist on a project dashboard
    def with_subprojects_available?(_schema)
      project.present?
    end
  end
end
