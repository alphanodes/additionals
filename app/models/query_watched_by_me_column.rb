# frozen_string_literal: true

class QueryWatchedByMeColumn < QueryColumn
  def initialize(queried_class)
    super :watched_by_me, caption: :field_watched_by_me, sortable: order_sql(queried_class)
  end

  # NOTE: we overwrite value_object, because we cannot change method name
  # rubocop: disable Naming/PredicateMethod
  def value_object(object)
    object.watched_by? User.current
  end
  # rubocop: enable Naming/PredicateMethod

  def order_sql(queried_class)
    watchable_type = queried_class == User ? 'Principal' : queried_class.to_s

    <<~SQL.squish
      COALESCE((SELECT 1 FROM #{Watcher.table_name}
      WHERE #{Watcher.table_name}.watchable_type='#{watchable_type}'
      AND #{Watcher.table_name}.watchable_id=#{queried_class.table_name}.id
      AND #{Watcher.table_name}.user_id=#{User.current.id}), 0)
    SQL
  end
end
