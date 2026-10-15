# frozen_string_literal: true

# Distribution of the entries of a query over one of its columns, counted or
# summed up. Subclasses bind it to a query class and to the list the chart
# links to; dashboard_block turns a subclass into a dashboard block.
#
# Grouping and totals come from core (result_count_by_group,
# total_by_group_for), so visibility, filters and the casting of custom field
# values behave exactly like the grouped list. Only custom fields with multiple
# values need an own count: core cannot group by them.
class AdditionalsQueryChart < AdditionalsChart
  CHART_TYPES = %w[doughnut pie bar_horizontal bar_vertical treemap table].freeze
  BAR_TYPES = %w[bar_horizontal bar_vertical].freeze
  ORDERS = %w[field value].freeze
  MEASURE_COUNT = 'count'
  # Filter types of columns without categories: dates and numbers would need
  # ranges, text has no categories, trees and relations no single value.
  # Everything else is a list of some kind, also the autocomplete types of
  # additionals (issue_assignee, author).
  NON_CATEGORY_FILTER_TYPES = %i[date date_past integer float string text search tree relation].freeze
  # Columns core shows as hours in the totals of a list
  HOURS_COLUMNS = %i[hours spent_hours total_spent_hours estimated_hours
                     total_estimated_hours estimated_remaining_hours].freeze

  # One slice of the chart, a row in the table of values. Each series links
  # to the list of its own query.
  Entry = Data.define :key, :label, :value, :compare_value, :url, :compare_url

  # Restricts a query to the default filters of its class on top of its own
  # filters. A filter of the same field cannot express that, it would replace
  # the one the query already has.
  module DefaultFiltersScope
    attr_accessor :default_filters_statement

    def base_scope
      super.where default_filters_statement
    end
  end

  class << self
    # Definition of a dashboard block showing this chart. Options extend or
    # replace the defaults, e.g. permission or if.
    def dashboard_block(label:, **options)
      { label:,
        max_occurs: DashboardContent::MAX_MULTIPLE_OCCURS,
        query_chart: { class: self },
        async: { required_settings: %i[group_by],
                 partial: 'dashboards/blocks/query_chart',
                 libraries: %i[chartjs_meta],
                 lazy: true,
                 data_check_class: self } }.merge(options)
    end
  end

  attr_reader :settings

  def initialize(project:, settings: {})
    @settings = settings.to_h.symbolize_keys
    super(project:)
    self.query = build_query @settings[:query_id]
  end

  def query_class
    raise 'overwrite it'
  end

  # The block offers to count only what the list shows by default (open
  # issues, valid entries), if the query class has default filters and the
  # subclass names them for the user
  def open_only_supported?
    open_only_label.present? && default_filters.any?
  end

  # Label of that option, e.g. :label_open_issues_only. Without one the
  # option is not offered: a generic text could not tell what it does.
  def open_only_label
    nil
  end

  def valid?
    entries.any? { |entry| entry.value.positive? || entry.compare_value.to_f.positive? }
  end

  def chart_type
    CHART_TYPES.include?(settings[:chart_type]) ? settings[:chart_type] : CHART_TYPES.first
  end

  def order
    ORDERS.include?(settings[:order]) ? settings[:order] : ORDERS.first
  end

  def bar_chart?
    BAR_TYPES.include? chart_type
  end

  def table_only?
    chart_type == 'table'
  end

  def treemap?
    chart_type == 'treemap'
  end

  def open_only?
    open_only_supported? && RedminePluginKit.true?(settings[:open_only])
  end

  # Both default to on, a new block has no settings yet
  def show_empty?
    settings[:show_empty].nil? || RedminePluginKit.true?(settings[:show_empty])
  end

  def with_table?
    table_only? || settings[:with_table].nil? || RedminePluginKit.true?(settings[:with_table])
  end

  # A comparison is a second series next to the first one, which only bars
  # and the table can show
  def compare?
    compare_query.present? && (bar_chart? || table_only?)
  end

  def group_column
    return if query.nil? || settings[:group_by].blank?

    @group_column ||= group_columns.detect { |column| column.name.to_s == settings[:group_by] }
  end

  def measure_column
    return if query.nil? || settings[:measure].blank? || settings[:measure] == MEASURE_COUNT
    return if multiple_values?

    @measure_column ||= measure_columns(query).detect { |column| column.name.to_s == settings[:measure] }
  end

  def hours_measure?
    measure_column.present? && HOURS_COLUMNS.include?(measure_column.name)
  end

  def measure_label
    measure_column ? measure_column.caption : l(:label_quantity)
  end

  # Columns whose values form categories: lists, users, versions, booleans and
  # the like. Dates and numbers would need ranges, free text has no categories.
  def group_columns
    @group_columns ||= options_query.available_columns.select { |column| group_column? column }
  end

  def group_options
    group_columns.map { |column| [column.caption, column.name.to_s] }
                 .sort_by! { |caption, _name| caption.to_s.downcase }
  end

  def measure_options
    [[l(:label_quantity), MEASURE_COUNT]] +
      measure_columns(options_query).map { |column| [column.caption, column.name.to_s] }
  end

  def title
    parts = [query&.persisted? ? query.name : l(entity_plural_label)]
    parts << group_column.caption if group_column
    parts.join Additionals::LIST_SEPARATOR
  end

  def series_labels
    labels = [query&.persisted? ? query.name : l(entity_plural_label)]
    labels << compare_query.name if compare?
    labels
  end

  def entries
    @entries ||= build_entries
  end

  def total
    entries.sum(&:value)
  end

  def share(entry)
    return 0 unless total.positive?

    (entry.value * 100.0 / total).round
  end

  # Data handed to the additionals-chart Stimulus controller
  def payload
    datasets = [series_dataset(series_labels.first, :value, :url)]
    datasets << series_dataset(series_labels.last, :compare_value, :compare_url) if compare?

    { type: chart_type,
      labels: entries.map(&:label),
      datasets:,
      total: total.round(2),
      totalLabel: measure_label,
      colorSchema: color_schema }
  end

  def height
    return CHART_DEFAULT_HEIGHT unless chart_type == 'bar_horizontal'

    [calc_bar_height(entries.size, compare? ? 2 : 1) + 40, 150].max
  end

  private

  def entity_plural_label
    raise 'overwrite it'
  end

  def list_path(_params)
    raise 'overwrite it'
  end

  # Column with the project of an entry, for the visibility of custom field values
  def custom_field_project_key
    raise 'overwrite it'
  end

  # Condition of the custom values a user may see, like core's grouping
  def custom_values_visibility(custom_field)
    custom_field.visibility_by_project_condition custom_field_project_key
  end

  # Operator and values of a filter as explicit values where possible, so a
  # filter of the query and a default filter of the same field can be joined
  # in the link of a slice, e.g. "open" as the ids of the open statuses
  def url_filter_values(_field, operator, values)
    [operator, values]
  end

  # Filters a new query of the class sets, e.g. open issues
  def default_filters
    @default_filters ||= query_class.new(name: '_').filters || {}
  end

  # Without project: the query of the chart restricts the projects already,
  # a project here would add its own subproject rule and drop entries a
  # subproject filter of the query includes
  def default_filters_statement
    @default_filters_statement ||= query_class.new(name: '_').statement
  end

  def series_dataset(label, value, url)
    { label:, data: entries.map(&value), urls: entries.map(&url) }
  end

  # The columns to choose from, also if the query of the block was deleted
  # or is not visible to the user editing the block - otherwise the settings
  # could not be saved anymore
  def options_query
    @options_query ||= query || build_query(nil)
  end

  def compare_query
    return if settings[:compare_query_id].blank?

    @compare_query ||= build_query settings[:compare_query_id]
  end

  def build_query(query_id)
    query = if query_id.present?
              # Exactly this class like the selection, not e.g. a subclass of another plugin
              query_class.visible.where(type: query_class.name).find_by id: query_id
            else
              # Without a query all visible entries count, not only the ones
              # a query class filters by default (e.g. open issues)
              query_class.new name: '_', filters: {}
            end
    return unless query

    query.project = project if project
    query.group_by = settings[:group_by]
    if open_only?
      query.extend DefaultFiltersScope
      query.default_filters_statement = default_filters_statement
    end
    prepare_query query
    query
  end

  # Hook for a subclass to adapt the query of the chart, not the list
  def prepare_query(_query); end

  # Columns a chart can sum up, the totals of the list by default
  def measure_columns(query)
    query.available_totalable_columns
  end

  def group_column?(column)
    return false unless column.groupable? || multiple_values_column?(column)

    type = filter_type_for column
    type.present? && NON_CATEGORY_FILTER_TYPES.exclude?(type)
  end

  # Custom fields tell their type by their format, also if they are no filter
  def filter_type_for(column)
    if column.is_a? QueryCustomFieldColumn
      custom_field = column.custom_field
      custom_field.format.query_filter_options(custom_field, options_query)[:type]
    else
      filter_name = filter_name_for column
      options_query.available_filters[filter_name][:type] if filter_name
    end
  end

  def multiple_values_column?(column)
    column.is_a?(QueryCustomFieldColumn) && column.custom_field.multiple?
  end

  def multiple_values?
    group_column.present? && multiple_values_column?(group_column)
  end

  def filter_name_for(column)
    name = column.name.to_s
    [name, "#{name}_id"].detect { |filter| options_query.available_filters.key? filter }
  end

  def build_entries
    return [] unless group_column

    values = grouped_values query
    compare_values = compare? ? grouped_values(compare_query) : {}

    keys = values.keys | compare_values.keys
    keys.delete nil unless show_empty?
    preload_version_projects keys

    entries = keys.filter_map do |key|
      value = values[key] || 0
      compare_value = compare_values[key] || 0
      next if value.zero? && compare_value.zero?

      Entry.new key:, label: entry_label(key), value:, compare_value:,
                url: entry_url(query, key),
                compare_url: compare? ? entry_url(compare_query, key) : nil
    end

    limit_entries sort_entries(entries)
  end

  # Versions of other projects are labeled with their project
  def preload_version_projects(keys)
    versions = keys.grep Version
    ActiveRecord::Associations::Preloader.new(records: versions, associations: :project).call if versions.any?
  end

  def grouped_values(query)
    return multiple_values_counts query if multiple_values?

    values = measure_column ? query.total_by_group_for(measure_column) : query.result_count_by_group
    values || {}
  end

  # Each selected value counts, so an entry with two values is part of two groups
  def multiple_values_counts(query)
    custom_field = group_column.custom_field
    custom_values = CustomValue.arel_table
    with_values = query.base_scope
                       .joins(:custom_values)
                       .where(custom_values: { custom_field_id: custom_field.id })
                       .where.not(custom_values: { value: [nil, ''] })
                       # values of a field visible to some roles only, like core's grouping
                       .where(custom_values_visibility(custom_field))

    # distinct: a query may join rows that repeat an entry, e.g. its projects
    counts = with_values.group(custom_values[:value]).distinct.count(:id)
                        .transform_keys { |value| custom_field.cast_value value }
    without = query.base_scope.where.not(id: with_values.select(:id)).distinct.count(:id)
    counts[nil] = without if without.positive?
    counts
  end

  def sort_entries(entries)
    return entries.sort_by { |entry| -entry.value } if order == 'value'

    entries.sort_by { |entry| field_sort_key entry.key }
  end

  # Order of the field itself: positions of statuses, trackers and
  # priorities, the possible values of a list, names otherwise. Entries
  # without a value come last.
  def field_sort_key(key)
    return [1, 0, ''] if key.nil?

    [0, field_position(key), key.to_s.downcase]
  end

  def field_position(key)
    if key.respond_to? :position
      key.position.to_i
    elsif key.is_a?(String) && group_column.is_a?(QueryCustomFieldColumn)
      group_column.custom_field.possible_values.index(key) || 0
    elsif key == false
      1
    else
      0
    end
  end

  # Small values first, then the largest entries up to the maximum. What does
  # not show becomes one entry "Others", so total and shares stay right.
  def limit_entries(entries)
    kept, others = split_small_entries entries
    max_entries = settings[:max_entries].to_i
    if max_entries.positive? && kept.size > max_entries
      largest = kept.max_by max_entries, &:value
      others += kept - largest
      kept = largest
    end
    return entries if others.empty?

    sort_entries(kept) << others_entry(others)
  end

  # Entries with a share below min_share percent of the first series
  def split_small_entries(entries)
    min_share = settings[:min_share].to_f
    sum = entries.sum(&:value)
    return [entries, []] unless min_share.positive? && sum.positive?

    entries.partition { |entry| entry.value * 100.0 / sum >= min_share }
  end

  def others_entry(others)
    Entry.new key: nil,
              label: l(:label_chart_others),
              value: others.sum(&:value),
              compare_value: others.sum(&:compare_value),
              url: nil,
              compare_url: nil
  end

  def entry_label(key)
    # Like the groups of the list the chart links to
    return "(#{l :label_blank_value})" if key.nil?
    # Versions of other projects carry the project, like format_version_name of core
    return key.to_s_with_project if key.is_a?(Version) && key.project != project
    return key.to_s if key.is_a? ActiveRecord::Base

    filter_value_labels[entry_value(key)] || plain_label(key)
  end

  def plain_label(key)
    case key
    when true then l(:general_text_Yes)
    when false then l(:general_text_No)
    else key.to_s
    end
  end

  def entry_value(key)
    case key
    when ActiveRecord::Base then key.id.to_s
    when true then '1'
    when false then '0'
    else key.to_s
    end
  end

  # Labels of values that are no records, e.g. yes and no or the status of a
  # project, as the filter of the column shows them
  def filter_value_labels
    @filter_value_labels ||= begin
      filter_name = filter_name_for group_column
      values = filter_name ? query.available_filters[filter_name][:values] : nil
      Array(values).to_h { |label, value| [value.to_s, label.to_s] }
    end
  end

  # Without a filter for the column, e.g. a custom field that is no filter,
  # the list cannot show the entries of a slice. Neither can it, if the
  # filters of the query and the default filters do not join into one.
  def entry_url(query, key)
    filter = filter_name_for group_column
    return unless filter

    filters = url_filters query, filter
    return unless filters

    params = { set_filter: 1, f: [], op: {}, v: {} }
    filters.each do |field, (operator, values)|
      add_url_filter params, field, operator, values unless field == filter
    end

    if key.nil?
      add_url_filter params, filter, '!*', ['']
    else
      add_url_filter params, filter, '=', [entry_value(key)]
    end

    list_path params
  end

  # The filters of the query, with open only joined with the default filters.
  # The group field is left out, the slice sets it.
  def url_filters(query, group_filter)
    filters = query.filters.to_h { |field, options| [field, [options[:operator], Array(options[:values])]] }
    return filters unless open_only?

    default_filters.each do |field, options|
      next if field == group_filter

      default = [options[:operator], Array(options[:values])]
      filters[field] = filters.key?(field) ? join_url_filters(field, filters[field], default) : default
      return nil unless filters[field]
    end
    filters
  end

  # Both filters of a field as one, nil if a list filter cannot express that
  def join_url_filters(field, own, default)
    # Any value of the query leaves the default filter as it is
    return default if own.first == '*'

    own = url_filter_values field, *own
    default = url_filter_values field, *default

    case [own.first, default.first]
    when %w[= =] then present_url_filter '=', own.last & default.last
    when %w[! =] then present_url_filter '=', default.last - own.last
    when %w[= !] then present_url_filter '=', own.last - default.last
    when %w[! !] then ['!', own.last | default.last]
    end
  end

  # No value left would be an empty filter, which the list rejects
  def present_url_filter(operator, values)
    [operator, values] if values.any?
  end

  def add_url_filter(params, field, operator, values)
    params[:f] << field
    params[:op][field] = operator
    params[:v][field] = values
  end
end
