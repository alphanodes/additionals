# frozen_string_literal: true

module DashboardBlocks
  class NewsBlock < Base
    block_id 'news'
    label :label_news_latest
    permission :view_news
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING, max: 1000
    setting :with_subprojects, type: :boolean, label: :label_cross_project_descendants,
                               if: ->(schema) { schema.context[:project].present? }

    def available?
      Redmine::AccessControl.active_module? :news
    end
  end
end
