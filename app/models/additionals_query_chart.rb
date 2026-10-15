# frozen_string_literal: true

# Distribution of the entries of a query over one of its columns, counted or
# summed up. Subclasses bind it to a query class and to the list the chart
# links to; dashboard_block turns a subclass into a dashboard block.
#
# Grouping and totals come from core (result_count_by_group,
# total_by_group_for), so visibility, filters and the casting of custom field
# values behave exactly like the grouped list. Only custom fields with multiple
# values need an own count: core cannot group by them. Dates are grouped by
# day like the list and summed up to periods, a timeline.
class AdditionalsQueryChart < AdditionalsChart
  CHART_TYPES = %w[doughnut pie bar_horizontal bar_vertical treemap line area table].freeze
  BAR_TYPES = %w[bar_horizontal bar_vertical].freeze
  LINE_TYPES = %w[line area].freeze
  # Types that show series: a comparison, the parts of a split or a timeline,
  # which has no shares of a whole like doughnut, pie and treemap show
  SERIES_TYPES = (BAR_TYPES + LINE_TYPES + %w[table]).freeze
  INTERVALS = %w[week month quarter year].freeze
  DEFAULT_INTERVAL = 'month'
  # More periods are no readable timeline, but a date entered wrongly, e.g. a
  # year 0202, would fill thousands of them up to the other dates
  MAX_PERIODS = 1000
  ORDERS = %w[field value].freeze
  MEASURE_COUNT = 'count'
  # Key of the entry or part that sums up the small values
  OTHERS = :others
  # A split shows a legend entry per part, about this many fit in a row
  LEGEND_ENTRIES_PER_ROW = 4
  LEGEND_ROW_HEIGHT = 25
  # Filter types of columns without categories: numbers would need ranges,
  # text has no categories, trees and relations no single value. Everything
  # else is a list of some kind, also the autocomplete types of additionals
  # (issue_assignee, author). Dates are summed up to periods.
  NON_CATEGORY_FILTER_TYPES = %i[integer float string text search tree relation].freeze
  DATE_FILTER_TYPES = %i[date date_past].freeze
  # Columns core shows as hours in the totals of a list
  HOURS_COLUMNS = %i[hours spent_hours total_spent_hours estimated_hours
                     total_estimated_hours estimated_remaining_hours].freeze

  # One slice of the chart, a row in the table of values. Each series links
  # to the list of its own query. Split by a second column, the parts are the
  # values per key of that column.
  Entry = Data.define :key, :label, :value, :compare_value, :url, :compare_url, :parts, :part_urls do
    def initialize(parts: {}, part_urls: {}, **)
      super
    end
  end

  # Restricts a query to the default filters of its class on top of its own
  # filters. A filter of the same field cannot express that, it would replace
  # the one the query already has.
  module DefaultFiltersScope
    attr_accessor :default_filters_statement

    def base_scope
      super.where default_filters_statement
    end
  end

  # Restricts a query to the days from the first period of a timeline on,
  # when the timeline shows the latest periods only
  module PeriodsScope
    attr_accessor :periods_condition

    def base_scope
      super.where periods_condition
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

  # A timeline is drawn as a line unless it is a type it can be shown as, a
  # category as vertical bars instead of a line
  def chart_type
    @chart_type ||= begin
      type = CHART_TYPES.include?(settings[:chart_type]) ? settings[:chart_type] : CHART_TYPES.first
      if timeline?
        SERIES_TYPES.include?(type) ? type : LINE_TYPES.first
      else
        LINE_TYPES.include?(type) ? 'bar_vertical' : type
      end
    end
  end

  def order
    ORDERS.include?(settings[:order]) ? settings[:order] : ORDERS.first
  end

  def interval
    INTERVALS.include?(settings[:interval]) ? settings[:interval] : DEFAULT_INTERVAL
  end

  # Grouped by a date, the entries are periods in the order of time
  def timeline?
    return @timeline if defined? @timeline

    @timeline = group_column.present? && date_column?(group_column)
  end

  def bar_chart?
    BAR_TYPES.include? chart_type
  end

  def line_chart?
    LINE_TYPES.include? chart_type
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

  # A comparison is a second series next to the first one, which only bars,
  # lines and the table can show. A split uses the series already.
  def compare?
    compare_query.present? && series_chart? && !split?
  end

  # Each entry split by a second column, as stacked bars or areas, lines or
  # a cross table. Two fields with multiple values would need two joins of
  # their values.
  def split?
    return @split if defined? @split

    @split = split_column.present? && series_chart? && (timeline? || split_column?(group_column)) &&
             !(multiple_values_column?(group_column) && multiple_values_column?(split_column))
  end

  def split_column
    return if group_column.nil? || settings[:split_by].blank? || settings[:split_by] == settings[:group_by]

    @split_column ||= split_columns.detect { |column| column.name.to_s == settings[:split_by] }
  end

  def split_columns
    @split_columns ||= group_columns.select { |column| split_column? column }
  end

  def split_options
    split_columns.map { |column| [column.caption, column.name.to_s] }
                 .sort_by! { |caption, _name| caption.to_s.downcase }
  end

  # Keys of the second column in the order of its field, small ones summed up
  # as OTHERS
  def split_keys
    entries
    @split_keys || []
  end

  def split_total(key)
    entries.sum { |entry| entry.parts[key] || 0 }
  end

  def split_label(key)
    key == OTHERS ? l(:label_chart_others) : entry_label(key, split_column)
  end

  def group_column
    return if query.nil? || settings[:group_by].blank?

    @group_column ||= group_columns.detect { |column| column.name.to_s == settings[:group_by] }
  end

  # What a block without a choice measures: counts by default, a subclass
  # may sum up a column instead, e.g. the hours of time entries
  def default_measure
    MEASURE_COUNT
  end

  def measure
    settings[:measure].presence || default_measure
  end

  def measure_column
    return if query.nil? || measure == MEASURE_COUNT
    return if multiple_values? || (split? && multiple_values_column?(split_column))

    @measure_column ||= measure_columns(query).detect { |column| column.name.to_s == measure }
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

  # Group columns that make a timeline, for the settings form
  def timeline_group_names
    group_columns.filter_map { |column| column.name.to_s if date_column? column }
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
    parts << split_column.caption if split?
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

  # With multiple values an entry is part of several groups, the total still
  # counts it once, like the list the chart links to
  def total
    @total ||= multiple_values? ? entry_count(query) : entries.sum(&:value)
  end

  def compare_total
    @compare_total ||= multiple_values? ? entry_count(compare_query) : entries.sum(&:compare_value)
  end

  # The groups add up to more than the total, so do their shares
  def counted_several_times?
    multiple_values? && entries.sum(&:value) > total
  end

  # Split by a field with multiple values, the parts of an entry add up to
  # more than the entry. Sums are rounded per part, so only counts tell.
  def parts_counted_several_times?
    split? && multiple_values_column?(split_column) &&
      entries.any? { |entry| entry.parts.values.sum > entry.value }
  end

  def share(entry)
    return 0 unless total.positive?

    (entry.value * 100.0 / total).round
  end

  # Data handed to the additionals-chart Stimulus controller. Lines of a
  # split cross each other, all other parts stack up.
  def payload
    { type: chart_type,
      labels: entries.map(&:label),
      datasets: payload_datasets,
      stacked: split? && chart_type != 'line',
      total: total.round(2),
      totalLabel: measure_label,
      colorSchema: color_schema }
  end

  def height
    bars_height = if chart_type == 'bar_horizontal'
                    [calc_bar_height(entries.size, compare? ? 2 : 1) + 40, 150].max
                  else
                    CHART_DEFAULT_HEIGHT
                  end
    bars_height + legend_height
  end

  private

  def series_chart?
    SERIES_TYPES.include? chart_type
  end

  # Room for the legend of a split, which would squeeze the bars otherwise
  def legend_height
    return 0 unless split?

    (split_keys.size.to_f / LEGEND_ENTRIES_PER_ROW).ceil * LEGEND_ROW_HEIGHT
  end

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

  def payload_datasets
    return split_keys.map { |key| split_dataset key } if split?

    datasets = [series_dataset(series_labels.first, :value, :url)]
    datasets << series_dataset(series_labels.last, :compare_value, :compare_url) if compare?
    datasets
  end

  def series_dataset(label, value, url)
    { label:, data: entries.map(&value), urls: entries.map(&url) }
  end

  def split_dataset(key)
    { label: split_label(key),
      data: entries.map { |entry| entry.parts[key] || 0 },
      urls: entries.map { |entry| entry.part_urls[key] } }
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

  # Columns a split may group by together with the group column: those whose
  # keys the base maps like core does. Columns of an own class may count their
  # groups or turn their keys into values themselves (e.g. a workflow name for
  # its id), which a grouping by two columns would bypass. A date would be a
  # timeline per part.
  def split_column?(column)
    (column.instance_of?(QueryColumn) || column.is_a?(QueryCustomFieldColumn)) && !date_column?(column)
  end

  # Columns a chart can sum up, the totals of the list by default
  def measure_columns(query)
    query.available_totalable_columns
  end

  # Fields of an associated entry, e.g. of the issue of a time entry, hold
  # their values there: core cannot group by them, and the count of fields
  # with multiple values would look for them on the entry itself
  def group_column?(column)
    return false if column.is_a? QueryAssociationCustomFieldColumn
    return false unless column.groupable? || multiple_values_column?(column)

    type = filter_type_for column
    return false if type.blank?
    return !multiple_values_column?(column) if DATE_FILTER_TYPES.include? type

    NON_CATEGORY_FILTER_TYPES.exclude? type
  end

  def date_column?(column)
    DATE_FILTER_TYPES.include? filter_type_for(column)
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

    [query, (compare_query if compare?)].compact.each { |series_query| limit_to_latest_periods series_query }
    values = period_values query, grouped_values(query)
    compare_values = compare? ? period_values(compare_query, grouped_values(compare_query)) : {}
    split_values = split? ? period_values(nil, split_values(query)) : {}

    keys = values.keys | compare_values.keys
    keys.delete nil unless show_empty?
    keys = timeline_periods keys if timeline?
    preload_version_projects keys

    entries = keys.filter_map do |key|
      value = values[key] || 0
      compare_value = compare_values[key] || 0
      # A period without entries keeps its place in the timeline
      next if value.zero? && compare_value.zero? && !timeline?

      Entry.new key:, label: entry_label(key), value:, compare_value:,
                url: entry_url(query, key),
                compare_url: compare? ? entry_url(compare_query, key) : nil,
                parts: split_values.fetch(key, {})
    end

    entries = limit_entries sort_entries(entries) unless timeline?
    split? ? split_entries(entries) : entries
  end

  # Values per day summed up per period, values of a split per part. The
  # days with values of a query bound its links if it filters the date itself.
  def period_values(query, values)
    return values unless timeline?

    day_ranges[query] = values.keys.filter_map { |key| key.presence&.to_date }.minmax if query
    values.each_with_object({}) do |(key, value), periods|
      next if key.blank?

      period = period_start key.to_date
      periods[period] = periods.key?(period) ? add_period_values(periods[period], value) : value
    end
  end

  def add_period_values(sum, value)
    sum.is_a?(Hash) ? sum.merge(value) { |_key, a, b| a + b } : sum + value
  end

  # Each query, the one of the chart and the one to compare to
  def day_ranges
    @day_ranges ||= {}.compare_by_identity
  end

  # With a maximum, only the latest periods show: the query counts from the
  # first of them on instead of grouping its whole history. The last day of
  # each query bounds its own periods, the timeline ends at the later one, so
  # no shown period loses entries. Custom fields keep their values in a joined
  # table, which the base scope has not, so they count everything.
  def limit_to_latest_periods(query)
    max_entries = settings[:max_entries].to_i
    return unless timeline? && max_entries.positive? && !group_column.is_a?(QueryCustomFieldColumn)

    sql = group_sql query.base_scope.klass, group_statement(query, group_column)
    days = query.base_scope.pick Arel.sql("MIN(#{sql})"), Arel.sql("MAX(#{sql})")
    return unless days&.last

    first = timeline_end days.last.to_date
    (max_entries - 1).times { first = period_start first - 1 }
    # The periods before the first entry stay out like without the limit
    first = [first, period_start(days.first.to_date)].max
    periods_start[query] = first
    query.extend PeriodsScope
    query.periods_condition = Arel.sql(sql).gteq(first)
  end

  # First period each query counts from, see limit_to_latest_periods
  def periods_start
    @periods_start ||= {}.compare_by_identity
  end

  # All periods from the first to the last one, the latest ones up to the
  # maximum. Without entries before or after, a timeline would only start
  # or end later, so it shows the periods with entries.
  def timeline_periods(keys)
    first, last = keys.minmax
    return [] unless last

    last = timeline_end last
    # Periods without entries at the start of the limited ones show, too
    first = [first, *periods_start.values].min

    max_entries = settings[:max_entries].to_i
    limit = max_entries.positive? ? [max_entries, MAX_PERIODS].min : MAX_PERIODS
    periods = [last]
    while periods.size < limit
      previous = period_start periods.last - 1
      break if previous < first

      periods << previous
    end
    periods.reverse
  end

  # Period the timeline ends with. Dates in the past only, e.g. created or
  # spent on, run up to today: weeks without entries since then are part of
  # what it shows. Other dates end with their last entry, they may lie in
  # the future.
  def timeline_end(last_day)
    return period_start last_day unless filter_type_for(group_column) == :date_past

    period_start [last_day, User.current.today].max
  end

  def period_start(date)
    case interval
    when 'week' then date - ((date.cwday - first_wday) % 7)
    when 'quarter' then date.beginning_of_quarter
    when 'year' then date.beginning_of_year
    else date.beginning_of_month
    end
  end

  def period_end(start)
    case interval
    when 'week' then start + 6
    when 'quarter' then start.end_of_quarter
    when 'year' then start.end_of_year
    else start.end_of_month
    end
  end

  # First day of a week as the calendar of core shows it, 1 = Monday ... 7 = Sunday
  def first_wday
    @first_wday ||= begin
      start_of_week = Setting.start_of_week.to_i
      start_of_week = l(:general_first_day_of_week).to_i unless [1, 6, 7].include? start_of_week
      ((start_of_week - 1) % 7) + 1
    end
  end

  # Weeks are numbered like in the calendar of core, by their Thursday
  def period_label(start)
    case interval
    when 'week'
      thursday = start + ((11 - start.cwday) % 7)
      l :label_chart_week, week: thursday.cweek, year: thursday.cwyear
    when 'quarter' then l(:label_chart_quarter, quarter: ((start.month - 1) / 3) + 1, year: start.year)
    when 'year' then start.year.to_s
    else
      l :label_chart_month, month: l('date.abbr_month_names')[start.month], year: start.year
    end
  end

  # Days of a period for the filter of its link. A filter of the query on the
  # same date would be replaced by it, so the days with entries keep its
  # bounds: a date filter always covers one range of days. Outside of them,
  # e.g. a period only the compared query has, nothing is left to link to.
  def period_filter_values(query, start)
    from = start
    to = period_end start
    first, last = day_ranges[query]
    if query.has_filter? filter_name_for(group_column)
      return unless first

      from = [from, first].max
      to = [to, last].min
    end
    [from.to_s, to.to_s] if from <= to
  end

  # Parts below min_share of all parts become OTHERS, the parts link to the
  # list filtered by both keys
  def split_entries(entries)
    sums = Hash.new 0
    entries.each { |entry| entry.parts.each { |key, value| sums[key] += value } }
    sums.delete nil unless show_empty?
    preload_version_projects sums.keys

    small = small_split_keys sums
    @split_keys = sums.keys.sort_by { |key| field_sort_key key, split_column } - small
    @split_keys << OTHERS if small.any?

    entries.map do |entry|
      parts = entry.parts.slice(*@split_keys)
      others = entry.parts.slice(*small).values.sum
      parts[OTHERS] = others if others.positive?
      part_urls = entry.key == OTHERS ? {} : split_urls(entry, parts.keys)
      entry.with parts:, part_urls:
    end
  end

  def small_split_keys(sums)
    min_share = settings[:min_share].to_f
    total_sum = sums.values.sum
    return [] unless min_share.positive? && total_sum.positive?

    sums.select { |_key, value| value * 100.0 / total_sum < min_share }.keys
  end

  def split_urls(entry, keys)
    keys.excluding(OTHERS).index_with { |key| entry_url query, entry.key, split_key: key }
  end

  # Values per key of the group and key of the split column
  def split_values(query)
    counts = if multiple_values_column?(group_column) || multiple_values_column?(split_column)
               multiple_split_counts query
             else
               split_counts query
             end
    counts.each_with_object({}) do |((key, split_key), value), values|
      (values[key] ||= {})[split_key] = value
    end
  end

  # distinct: a query may join rows that repeat an entry, e.g. its projects
  def split_counts(query)
    columns = [group_column, split_column]
    scope = query.base_scope
    statements = columns.map { |column| group_statement query, column }
    grouped = scope.joins(query_joins(query, statements))
                   .group(*statements.map { |statement| group_sql scope.klass, statement })
    values = measure_column ? query.send(:total_with_scope, measure_column, grouped) : grouped.distinct.count(:id)
    map_split_keys scope.klass, values, columns.zip(statements)
  end

  # Each selected value counts, like the entries of a field with multiple values
  def multiple_split_counts(query)
    multiple, other = [group_column, split_column].partition { |column| multiple_values_column? column }.flatten
    with_values = with_values_scope query, multiple.custom_field
    statement = group_statement query, other
    klass = with_values.klass
    other_sql = group_sql klass, statement

    counts = with_values.joins(query_joins(query, [statement]))
                        .group(other_sql, CustomValue.arel_table[:value]).distinct.count(:id)
                        .to_h { |(other_key, value), count| [[other_key, value], count] }
    query.base_scope.where.not(id: with_values.select(:id))
         .joins(query_joins(query, [statement]))
         .group(other_sql).distinct.count(:id)
         .each { |other_key, count| counts[[other_key, nil]] = count }

    # Keys as [group, split]
    counts = map_split_keys klass, counts, [[other, statement], [multiple, nil]]
    return counts if other == group_column

    counts.transform_keys(&:reverse)
  end

  # Statement of a column as the query groups by it. A query class may
  # decide that itself, e.g. for columns of its own.
  def group_statement(query, column)
    group_by = query.group_by
    query.group_by = column.name.to_s
    query.group_by_statement
  ensure
    query.group_by = group_by
  end

  # Joins the statements need, e.g. the values of a custom field
  def query_joins(query, statements)
    query.send :joins_for_order_statement, statements.join(',')
  end

  # SQL to group by a statement. Grouped by a single column, ActiveRecord
  # turns an association name into its records, grouped by two it does not:
  # the foreign key is grouped by then, see map_split_keys. The class of the
  # scope counts, not the one of the query (e.g. User for Principal).
  def group_sql(klass, statement)
    reflection = klass.reflect_on_association statement.to_sym
    if reflection&.belongs_to?
      "#{klass.table_name}.#{reflection.foreign_key}"
    elsif klass.column_names.include? statement
      "#{klass.table_name}.#{statement}"
    else
      statement
    end
  end

  # Keys as records and cast values, like core returns the keys of one
  # column. Each key is cast once, a user or version field loads its record.
  def map_split_keys(klass, values, columns)
    mappers = columns.each_with_index.map do |(column, statement), index|
      split_key_mapper klass, column, statement, values.keys.pluck(index).uniq
    end
    # Keys that map to the same one, e.g. NULL and '' as no value, add up
    values.each_with_object({}) do |(keys, value), mapped|
      key = keys.each_with_index.map { |raw, index| mappers[index][raw] }
      mapped[key] = (mapped[key] || 0) + value
    end
  end

  def split_key_mapper(klass, column, statement, keys)
    if column.is_a? QueryCustomFieldColumn
      keys.index_with { |key| key.presence && column.custom_field.cast_value(key) }
    elsif (reflection = klass.reflect_on_association statement.to_sym) && reflection.belongs_to?
      records = reflection.klass.where(id: keys.compact).index_by(&:id)
      keys.index_with { |key| records[key] }
    else
      keys.index_with { |key| key == '' ? nil : key }
    end
  end

  # Versions of other projects are labeled with their project
  def preload_version_projects(keys)
    versions = keys.grep Version
    ActiveRecord::Associations::Preloader.new(records: versions, associations: :project).call if versions.any?
  end

  def grouped_values(query)
    return multiple_values_counts query if multiple_values?

    values = measure_column ? query.total_by_group_for(measure_column) : query.result_count_by_group
    merge_blank_keys values || {}
  end

  # A column may hold NULL and an empty string for no value, the list shows
  # both as one group without value
  def merge_blank_keys(values)
    return values unless values.key? ''

    values = values.dup
    blank = values.delete ''
    values[nil] = (values[nil] || 0) + blank
    values
  end

  # Each selected value counts, so an entry with two values is part of two groups
  def multiple_values_counts(query)
    custom_field = group_column.custom_field
    with_values = with_values_scope query

    # distinct: a query may join rows that repeat an entry, e.g. its projects
    counts = with_values.group(CustomValue.arel_table[:value]).distinct.count(:id)
                        .transform_keys { |value| custom_field.cast_value value }
    without = query.base_scope.where.not(id: with_values.select(:id)).distinct.count(:id)
    counts[nil] = without if without.positive?
    counts
  end

  def with_values_scope(query, custom_field = group_column.custom_field)
    query.base_scope
         .joins(:custom_values)
         .where(custom_values: { custom_field_id: custom_field.id })
         .where.not(custom_values: { value: [nil, ''] })
         # values of a field visible to some roles only, like core's grouping
         .where(custom_values_visibility(custom_field))
  end

  # Entries of the chart, each counted once
  def entry_count(query)
    scope = show_empty? ? query.base_scope : with_values_scope(query)
    scope.distinct.count :id
  end

  def sort_entries(entries)
    return entries.sort_by { |entry| -entry.value } if order == 'value'

    entries.sort_by { |entry| field_sort_key entry.key, group_column }
  end

  # Order of the field itself: positions of statuses, trackers and
  # priorities, the possible values of a list, names otherwise. Entries
  # without a value come last.
  def field_sort_key(key, column)
    return [1, 0, ''] if key.nil?

    [0, field_position(key, column), key.to_s.downcase]
  end

  def field_position(key, column)
    if key.respond_to? :position
      key.position.to_i
    elsif key.is_a?(String) && column.is_a?(QueryCustomFieldColumn)
      column.custom_field.possible_values.index(key) || 0
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

  # Entries with a share below min_share percent of the first series, the
  # share as the table shows it
  def split_small_entries(entries)
    min_share = settings[:min_share].to_f
    sum = multiple_values? ? total : entries.sum(&:value)
    return [entries, []] unless min_share.positive? && sum.positive?

    entries.partition { |entry| entry.value * 100.0 / sum >= min_share }
  end

  def others_entry(others)
    Entry.new key: OTHERS,
              label: l(:label_chart_others),
              value: others.sum(&:value),
              compare_value: others.sum(&:compare_value),
              url: nil,
              compare_url: nil,
              parts: others.map(&:parts).reduce({}) { |sum, parts| sum.merge(parts) { |_key, a, b| a + b } }
  end

  def entry_label(key, column = group_column)
    # Like the groups of the list the chart links to
    return "(#{l :label_blank_value})" if key.nil?
    return period_label key if column == group_column && timeline?
    # Versions of other projects carry the project, like format_version_name of core
    return key.to_s_with_project if key.is_a?(Version) && key.project != project
    return key.to_s if key.is_a? ActiveRecord::Base

    filter_value_labels(column)[entry_value(key)] || plain_label(key)
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
  def filter_value_labels(column)
    @filter_value_labels ||= {}
    @filter_value_labels[column.name] ||= begin
      filter_name = filter_name_for column
      values = filter_name ? query.available_filters[filter_name][:values] : nil
      Array(values).to_h { |label, value| [value.to_s, label.to_s] }
    end
  end

  # Without a filter for the column, e.g. a custom field that is no filter,
  # the list cannot show the entries of a slice. Neither can it, if the
  # filters of the query and the default filters do not join into one.
  # The link of a part filters by its key of the split column, too. A period
  # filters by its days.
  def entry_url(query, key, **part)
    keys = { group_column => key }
    keys[split_column] = part[:split_key] if part.key? :split_key
    key_filters = keys.transform_keys { |column| filter_name_for column }
    return if key_filters.key? nil

    filters = url_filters query, key_filters.keys
    return unless filters

    period = period_filter_values query, key if timeline?
    return if timeline? && period.nil?

    params = { set_filter: 1, f: [], op: {}, v: {} }
    filters.each do |field, (operator, values)|
      add_url_filter params, field, operator, values unless key_filters.key? field
    end

    key_filters.each do |filter, filter_key|
      if filter_key.nil?
        add_url_filter params, filter, '!*', ['']
      elsif period && filter == key_filters.keys.first
        add_url_filter params, filter, '><', period
      else
        add_url_filter params, filter, '=', [entry_value(filter_key)]
      end
    end

    list_path params
  end

  # The filters of the query, with open only joined with the default filters.
  # The group fields are left out, the slice sets them.
  def url_filters(query, key_filters)
    filters = query.filters.to_h { |field, options| [field, [options[:operator], Array(options[:values])]] }
    return filters unless open_only?

    default_filters.each do |field, options|
      next if key_filters.include? field

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
