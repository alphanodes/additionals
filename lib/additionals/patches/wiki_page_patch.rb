# frozen_string_literal: true

module Additionals
  module Patches
    # Patch wiki to include sidebar
    module WikiPagePatch
      extend ActiveSupport::Concern

      class_methods do
        def my_watched_pages(user = User.current)
          eager_load(:wiki).joins("INNER JOIN #{Watcher.table_name}" \
                                  " ON #{Watcher.table_name}.watchable_id = #{WikiPage.table_name}.id" \
                                  " AND #{Watcher.table_name}.watchable_type = 'WikiPage'")
                           .joins("INNER JOIN #{Project.table_name}" \
                                  " ON #{Wiki.table_name}.project_id = #{Project.table_name}.id")
                           .where(watchers: { user_id: user.id })
                           .where(Project.allowed_to_condition(user,
                                                               :view_wiki_pages,
                                                               pre_condition_project_field: "#{Wiki.table_name}.project_id"))
                           .order(Watcher.arel_table['id'].desc)
        end
      end
    end
  end
end
