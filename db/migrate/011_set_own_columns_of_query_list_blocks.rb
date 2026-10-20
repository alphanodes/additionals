# frozen_string_literal: true

# Query list blocks used their stored columns, now only with own columns, else
# the columns of their query. The forms stored the columns with every save, so
# most blocks only hold a copy of the columns of their query: these follow
# their query from now on. A block with other columns gets own columns and
# keeps showing them, also whenever the columns of its query cannot be read
# (e.g. the query was deleted or belongs to a plugin no longer installed).
class SetOwnColumnsOfQueryListBlocks < ActiveRecord::Migration[7.2]
  def up
    Dashboard.find_each do |dashboard|
      options = dashboard.options
      next unless options.is_a?(Hash) && options[:layout_settings].is_a?(Hash)

      changed = options[:layout_settings].values.count { |settings| convert_columns settings }
      dashboard.update_column :options, options if changed.positive?
    end
  end

  def down
    # Nothing to restore: own_columns is ignored without the setting
  end

  private

  # Settings keep the kind of their keys, symbols or strings
  def convert_columns(settings)
    return false unless settings.is_a? Hash

    key = [:columns, 'columns'].find { |name| settings[name].present? }
    query_id = settings[:query_id] || settings['query_id']
    return false if key.nil? || query_id.blank?

    if Array(settings[key]).map(&:to_s) == columns_of_query(query_id)
      settings.delete key
    else
      settings[key.is_a?(Symbol) ? :own_columns : 'own_columns'] = '1'
    end
    true
  end

  # The columns the query shows, its defaults if it has none, without those
  # always shown (frozen, e.g. the id) like the column selection; nil if they
  # cannot be read
  def columns_of_query(query_id)
    query = Query.find_by id: query_id
    return if query.nil?

    query.columns.filter_map { |column| column.name.to_s unless column.frozen? }
  rescue StandardError
    nil
  end
end
