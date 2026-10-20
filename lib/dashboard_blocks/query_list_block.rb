# frozen_string_literal: true

module DashboardBlocks
  # Entries of a saved query as list, e.g. issues
  class QueryListBlock < Base
    abstract!

    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS

    setting :query_id, type: :enum, label: :label_query, required: true
    setting :max_entries, **DashboardContent::MAX_ENTRIES_SETTING
    setting :auto_refresh, type: :boolean, label: :label_enable_auto_refresh
    # Without own columns the list follows the columns of its query. Both
    # belong to the stored query, another one drops them. Last in the form,
    # the column selection opens below its checkbox.
    setting :own_columns, type: :boolean, label: :label_query_own_columns, reset_by: :query_id
    # The column selection of the query, see columns_applies?
    setting :columns, type: :list, label: :field_column_names, field: 'dashboards/settings/query_columns', wide: true,
                      shown_with: :own_columns, reset_by: :query_id

    class_attribute :query_block_options, instance_writer: false

    class << self
      # The list of the query: a label is a locale key, the query class is
      # named as a string (see Base). export_without names columns programs
      # never read (export_data), e.g. encrypted values
      def query_block(**options)
        options.any? ? self.query_block_options = options : query_block_options
      end
    end

    # The list of the query with its label translated and its class
    def query_block
      options = self.class.query_block
      options.merge label: I18n.t(options[:label]), class: query_class
    end

    # A query list loads after the page, lazily and sorted by its own links;
    # a subclass may change these options with async
    def async
      { required_settings: %i[query_id],
        exposed_params: %i[sort],
        partial: 'dashboards/blocks/query_list',
        query_block:,
        lazy: true }.merge(super || {})
    end

    # The saved query of the settings with the chosen columns, nil if the user
    # cannot see it
    def query
      return @query if defined? @query

      @query = query_id.present? ? query_class.visible.find_by(id: query_id) : nil
      return if @query.nil?

      @query.project = project if self.class.query_block[:with_project]
      @query.column_names = columns.map(&:to_sym) if own_columns && columns.present?
      @query
    end

    # The entries of the query, sorted by sort (the sort param of a list) if
    # given; nil without a query
    def data(sort: nil)
      return if query.nil?

      query.sort_criteria = sort if sort.present?
      count = query.send self.class.query_block[:count_method] || 'query_count'
      entries = count.positive? ? query.send(self.class.query_block[:entries_method] || 'entries', limit: max_entries) : []
      { query:, count:, entries: }
    end

    # The columns of the query and a row of values per entry
    def export_data
      list = data
      return if list.nil?

      excluded = Array self.class.query_block[:export_without]
      columns = list[:query].inline_columns.reject { |column| excluded.include? column.name }
      { query: list[:query].name,
        count: list[:count],
        columns: columns.map { |column| column.caption.to_s },
        rows: list[:entries].map { |entry| columns.map { |column| export_value column.value_object(entry) } } }
    end

    private

    def query_class
      self.class.query_block[:class].to_s.constantize
    end

    def query_id_values(_schema)
      DashboardContent.selectable_queries(query_class, project).map { |query| [query.name, query.id.to_s] }
    end

    # The columns belong to the stored query, a new block chooses them after
    # its query was saved
    def columns_applies?(schema)
      schema.stored(:query_id).present?
    end

    def own_columns_applies?(schema)
      columns_applies? schema
    end

    # Columns of the chosen query as its settings form offers them (without a
    # project), nil without a query: then there is nothing to check. The stored
    # ones stay valid when another query of the block has not all of them,
    # e.g. a custom field column.
    def columns_values(schema)
      query = query_class.find_by id: schema[:query_id] if schema[:query_id].present?
      return if query.nil?

      values = query.available_columns.filter_map { |column| [column.caption, column.name.to_s] unless column.frozen? }
      stored = Array(schema.stored(:columns)) - values.map(&:last)
      values + stored.map { |name| [name, name] }
    end
  end
end
