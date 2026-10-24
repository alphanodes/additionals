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
  CHART_TYPES = %w[doughnut pie bar_horizontal bar_vertical treemap line area calendar table].freeze
  BAR_TYPES = %w[bar_horizontal bar_vertical].freeze
  LINE_TYPES = %w[line area].freeze
  # Types that show series: a comparison, the parts of a split or a timeline,
  # which has no shares of a whole like doughnut, pie and treemap show
  SERIES_TYPES = (BAR_TYPES + LINE_TYPES + %w[table]).freeze
  # A calendar shows the days of a year, like a series only for a timeline
  TIMELINE_ONLY_TYPES = (LINE_TYPES + %w[calendar]).freeze
  TIMELINE_TYPES = (SERIES_TYPES + %w[calendar]).freeze
  # Weeks of a calendar up to today, a year in columns of weeks
  CALENDAR_WEEKS = 53
  CALENDAR_HEIGHT = 190
  # Days with values are split into levels of about the same number of days
  CALENDAR_QUANTILES = [0.25, 0.5, 0.75].freeze
  INTERVALS = %w[week month quarter year].freeze
  # A calendar shows days, which are no choice of the form
  INTERVAL_LABELS = { 'day' => :label_chart_interval_day, 'week' => :label_week, 'month' => :label_month,
                      'quarter' => :label_chart_interval_quarter, 'year' => :label_year }.freeze
  DEFAULT_INTERVAL = 'month'
  # Relative periods of the date filters of core a block can count in, with
  # the unit their previous period and its label go by
  PERIODS = { 'w' => 'week', 'lw' => 'week', 'm' => 'month', 'lm' => 'month', 'y' => 'year' }.freeze
  PERIOD_LABELS = { 'w' => :label_this_week, 'lw' => :label_last_week, 'm' => :label_this_month,
                    'lm' => :label_last_month, 'y' => :label_this_year }.freeze
  # Fixed periods, from a day up to today or between two days (settings
  # period_from, period_to). Unlike the relative ones they bound a timeline.
  # The operators of the date filters of core name them
  FIXED_PERIOD_LABELS = { 'from' => :label_greater_or_equal, 'between' => :label_between }.freeze
  # Comparison with the period before the one of the block
  PREVIOUS_PERIOD = 'previous'
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
  # Numbers are summed up to classes of their values
  NUMBER_FILTER_TYPES = %i[integer float hour].freeze
  # Automatic classes split the values into about this many of the same width
  AUTOMATIC_CLASSES = 5
  # Classes given in the settings, each one more query when summed up
  MAX_CLASSES = 50
  # The number filters know no "below": the upper bound of a class of decimals
  # stays just below the next one
  CLASS_BOUND_GAP = 0.000001
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

  # A value of the table of values. The part of a split links to the list of
  # its entries and is left empty without any, like in a cross table.
  TableCell = Data.define :value, :url, :part

  # Restricts a query to the default filters of its class on top of its own
  # filters. A filter of the same field cannot express that, it would replace
  # the one the query already has.
  module DefaultFiltersScope
    attr_accessor :default_filters_statement

    def base_scope
      super.where default_filters_statement
    end
  end

  # Restricts a query to a period of the date the chart counts by
  module DatePeriodScope
    attr_accessor :period_filter, :period_statement

    def base_scope
      super.where period_statement
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
    return false if unavailable_text

    entries.any? { |entry| entry.value.positive? || entry.compare_value.to_f.positive? }
  end

  # Text of a value in chart, table of values and total, nil formats it like
  # the totals of the list. A subclass formats e.g. amounts with their currency.
  def value_text(_value)
    nil
  end

  # Why the chart cannot be drawn with these settings, shown instead of it.
  # nil draws it, e.g. a subclass refuses to add up amounts of different
  # currencies.
  def unavailable_text
    nil
  end

  # A timeline is drawn as a line unless it is a type it can be shown as, a
  # category as vertical bars instead of a line
  def chart_type
    @chart_type ||= begin
      type = CHART_TYPES.include?(settings[:chart_type]) ? settings[:chart_type] : CHART_TYPES.first
      if timeline?
        TIMELINE_TYPES.include?(type) ? type : LINE_TYPES.first
      else
        TIMELINE_ONLY_TYPES.include?(type) ? 'bar_vertical' : type
      end
    end
  end

  def order
    ORDERS.include?(settings[:order]) ? settings[:order] : ORDERS.first
  end

  # A calendar shows single days
  def interval
    return 'day' if calendar?

    INTERVALS.include?(settings[:interval]) ? settings[:interval] : DEFAULT_INTERVAL
  end

  def calendar?
    chart_type == 'calendar'
  end

  # Grouped by a date, the entries are periods in the order of time
  def timeline?
    return @timeline if defined? @timeline

    @timeline = group_column.present? && date_column?(group_column)
  end

  # Grouped by a number, the entries are classes of its values
  def number_classes?
    return @number_classes if defined? @number_classes

    @number_classes = group_column.present? && number_column?(group_column)
  end

  # Bounds of the classes as given, or round steps over all values. Whole
  # numbers know no bound between two of them, 2.5 is 3 for them.
  def class_bounds
    @class_bounds ||= begin
      bounds = settings[:classes].to_s.split(/;|,\s+|\s+/).filter_map { |bound| Float(bound.tr(',', '.'), exception: false) }
      bounds.map!(&:ceil) if integer_column? group_column
      bounds.any? ? bounds.uniq.sort!.first(MAX_CLASSES) : automatic_class_bounds
    end
  end

  def bar_chart?
    BAR_TYPES.include? chart_type
  end

  # From the setting, a payload without entries has no calendar to build
  def icon
    self.class.type_icon chart_type
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

  # A table of the days of a year would be longer than the calendar tells
  def with_table?
    return false if calendar?

    table_only? || table_chosen?
  end

  # The choice of the settings form, kept for a calendar: another display type
  # shows the table again
  def table_chosen?
    settings[:with_table].nil? || RedminePluginKit.true?(settings[:with_table])
  end

  # Date filter a period of the block applies to, e.g. the day of a time
  # entry. Without one the block offers no period.
  def period_field
    nil
  end

  def period_supported?
    period_field.present?
  end

  # Name of the date the period applies to, as its filter names it
  def period_caption
    options_query.available_filters[period_field]&.[](:name) if period_supported?
  end

  # A timeline shows its periods itself, a fixed period bounds them, also
  # without a date of the period of the block: it bounds the date of the
  # timeline. A fixed period without its days is none.
  def period
    code = settings[:period]
    if FIXED_PERIOD_LABELS.key? code
      code if (timeline? || period_supported?) && fixed_range(code)
    elsif period_supported? && !timeline? && PERIODS.key?(code)
      code
    end
  end

  # A block offers a period with a date of its period, or for a timeline
  def period_offered?
    period_supported? || timeline_group_names.any?
  end

  def fixed_period?
    FIXED_PERIOD_LABELS.key? period
  end

  # First and last day of a fixed period, nil with a day missing or the end
  # before the start
  def fixed_range(code = period)
    from = setting_date :period_from
    to = code == 'between' ? setting_date(:period_to) : User.current.today
    [from, to] if from && to && from <= to
  end

  # The period as the title and the summary name it
  def period_text
    return l PERIOD_LABELS[period] unless fixed_period?

    from, to = fixed_range.map { |day| format_date day }
    period == 'from' ? l(:label_chart_period_since, date: from) : l(:label_date_from_to, start: from, end: to)
  end

  # The period of a distribution below its chart where an own title hides it
  # from the one of the block; a timeline shows its days on the axis
  def period_note
    "#{period_caption}: #{period_text}" if period && !timeline? && settings[:title].present?
  end

  # The date a period applies to: the one of the block, the date of a timeline
  def period_scope_caption
    timeline? ? group_column.caption : period_caption
  end

  # Compared with the period before, of a distribution only: a timeline of
  # another period would not lie on the same axis
  def previous_period?
    period.present? && !timeline? && settings[:compare_query_id] == PREVIOUS_PERIOD
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

    @split = split_column.present? && series_chart? && (timeline? || number_classes? || split_column?(group_column)) &&
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

  # Split columns the settings offer for the group column: never the group
  # column itself, and no second field with multiple values
  def offered_split_names
    split_columns.filter_map do |column|
      next if column == group_column || (multiple_values? && multiple_values_column?(column))

      column.name.to_s
    end
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

  # Group columns whose values form classes, for the settings form
  def number_group_names
    group_columns.filter_map { |column| column.name.to_s if number_column? column }
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
    parts = [source_label]
    parts << group_column.caption if group_column
    parts << split_column.caption if split?
    parts << "#{period_scope_caption}: #{period_text}" if period
    parts.join Additionals::LIST_SEPARATOR
  end

  # What the chart shows, for its settings form: the measure per group with
  # split, comparison and display type, then the options that restrict the
  # entries. Values stay as they are, so the sentence fits every language.
  def summary
    return l :label_chart_summary_without_group unless group_column

    details = summary_details.map { |key, value| l key, value: }.join
    sentence = l summary_key, source: source_label, measure: measure_label, group: group_column.caption,
                              interval: l(INTERVAL_LABELS[interval]), details: details
    [sentence, *summary_restrictions].join ' '
  end

  # Saved queries of the chart with a description, which tells the reader
  # where the values come from
  def described_queries
    queries = [query]
    queries << compare_query if compare? && !previous_period? && compare_query.id != query&.id
    queries.select { |series_query| series_query&.persisted? && series_query.description.present? }
  end

  def query_url(query)
    list_path query_id: query.id
  end

  # Compared with the period before, both series are named by their period
  def series_labels
    return previous_period_labels if previous_period? && compare?

    labels = [source_label]
    labels << compare_query.name if compare?
    labels
  end

  def entries
    @entries ||= build_entries
  end

  # The table of values reads a timeline from the latest period down, the
  # chart from left to right in the order of time
  def table_entries
    timeline? ? entries.reverse : entries
  end

  # The table of values with raw values, for the block and for programs: the
  # captions of the value columns next to the group, the cells of an entry
  # and the totals, column by column. A split has a column per part and the
  # sum, a comparison one per series.
  def value_columns
    return split_keys.map { |key| split_label key } + [measure_label] if split?

    compare? ? series_labels : [measure_label]
  end

  def entry_cells(entry)
    cells = split? ? split_keys.map { |key| TableCell.new(entry.parts[key] || 0, entry.part_urls[key], true) } : []
    cells << TableCell.new(entry.value, nil, false)
    cells << TableCell.new(entry.compare_value, nil, false) if compare?
    cells
  end

  def value_totals
    totals = split? ? split_keys.map { |key| split_total key } : []
    totals << total
    totals << compare_total if compare?
    totals
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
      colorSchema: color_schema }.merge(type_payload)
  end

  def height
    return CALENDAR_HEIGHT if calendar?

    bars_height = if chart_type == 'bar_horizontal'
                    [calc_bar_height(entries.size, compare? ? 2 : 1) + 40, 150].max
                  else
                    CHART_DEFAULT_HEIGHT
                  end
    bars_height + legend_height
  end

  private

  # Options only one chart type knows
  def type_payload
    if calendar?
      { calendar: calendar_payload }
    elsif treemap?
      { restLabel: l(:label_chart_others) }
    else
      {}
    end
  end

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

  def summary_key
    if timeline?
      :label_chart_summary_timeline
    elsif number_classes?
      :label_chart_summary_classes
    else
      :label_chart_summary
    end
  end

  # The saved query, otherwise what the chart counts
  def source_label
    query&.persisted? ? query.name : l(entity_plural_label)
  end

  def summary_details
    details = []
    details << [:label_chart_summary_split, split_column.caption] if split?
    details << [:label_chart_summary_compare, previous_period? ? l(:label_chart_previous_period) : compare_query.name] if compare?
    details << [:label_chart_summary_display, l(:"label_chart_type_#{chart_type}")]
  end

  # Sentences of their own, the options name themselves
  def summary_restrictions
    restrictions = []
    restrictions << "#{l open_only_label}." if open_only?
    restrictions << "#{period_scope_caption}: #{period_text}." if period
    restrictions
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

  # The previous period compares the query of the block with itself
  def compare_query
    return if settings[:compare_query_id].blank?
    return if settings[:compare_query_id] == PREVIOUS_PERIOD && !period

    @compare_query ||= build_query previous_period? ? settings[:query_id] : settings[:compare_query_id]
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
    (column.instance_of?(QueryColumn) || column.is_a?(QueryCustomFieldColumn)) &&
      !date_column?(column) && !number_type?(column)
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
    return number_column? column if number_type? column
    return false unless column.groupable? || multiple_values_column?(column)

    type = filter_type_for column
    return false if type.blank?
    return !multiple_values_column?(column) if DATE_FILTER_TYPES.include? type

    NON_CATEGORY_FILTER_TYPES.exclude? type
  end

  def date_column?(column)
    DATE_FILTER_TYPES.include? filter_type_for(column)
  end

  def number_type?(column)
    NUMBER_FILTER_TYPES.include? filter_type_for(column)
  end

  # Numbers stored in a column of the entry or in a custom field. Computed
  # columns, e.g. counts of notes, are subqueries per entry: grouping by them
  # would count for every entry and each plugin builds them its own way.
  def number_column?(column)
    return false unless number_type?(column) && !multiple_values_column?(column)
    return true if column.is_a? QueryCustomFieldColumn

    column.instance_of?(QueryColumn) && options_query.queried_class.column_names.include?(column.name.to_s)
  end

  def integer_column?(column)
    filter_type_for(column) == :integer
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

    apply_periods
    [query, (compare_query if compare?)].compact.each { |series_query| limit_to_latest_periods series_query }
    values = bucket_values query, grouped_values(query)
    compare_values = compare? ? bucket_values(compare_query, grouped_values(compare_query)) : {}
    split_values = split? ? bucket_values(nil, split_values(query)) : {}

    keys = values.keys | compare_values.keys
    keys.delete nil unless show_empty?
    keys = timeline_periods keys if timeline?
    keys = entry_classes keys if number_classes?
    preload_version_projects keys

    entries = keys.filter_map do |key|
      value = values[key] || 0
      compare_value = compare_values[key] || 0
      # A period or class without entries keeps its place
      next if value.zero? && compare_value.zero? && !timeline? && !(number_classes? && key)

      Entry.new key:, label: entry_label(key), value:, compare_value:,
                url: entry_url(query, key),
                compare_url: compare? ? entry_url(compare_query, key) : nil,
                parts: split_values.fetch(key, {})
    end

    entries = limit_entries sort_entries(entries) unless timeline? || number_classes?
    split? ? split_entries(entries) : entries
  end

  # Every class keeps its place, entries without a value come last
  def entry_classes(keys)
    class_keys.reject { |key| key.nil? && keys.exclude?(nil) }
  end

  # Days summed up to periods; numbers come as classes already
  def bucket_values(query, values)
    return values if number_classes?

    period_values query, values
  end

  # Round steps of the same width from the smallest to the largest value
  def automatic_class_bounds
    apply_periods
    scope = number_scope query
    number = number_expression scope.klass, group_column
    first, last = scope.where.not(no_number_condition(scope.klass, group_column)).pick(number.minimum, number.maximum)
    return [] unless first

    first = first.to_f
    last = last.to_f

    step = class_step last - first
    bound = ((first / step).floor * step) + step
    bounds = []
    while bound <= last && bounds.size < MAX_PERIODS
      bounds << bound
      bound += step
    end
    bounds.empty? ? [last] : bounds
  end

  # 1, 2 or 5 times a power of ten, whole numbers for integer columns
  def class_step(span)
    raw = span.to_f / AUTOMATIC_CLASSES
    return 1 unless raw.positive?

    magnitude = 10**Math.log10(raw).floor
    step = [1, 2, 5, 10].map { |factor| factor * magnitude }.detect { |candidate| candidate >= raw }
    integer_column?(group_column) ? [step.ceil, 1].max : step
  end

  def class_label(index)
    bounds = class_bounds
    if index.zero?
      l :label_chart_class_below, value: format_bound(bounds.first)
    elsif index == bounds.size
      l :label_chart_class_from, value: format_bound(bounds.last)
    else
      l :label_chart_class_range, from: format_bound(bounds[index - 1]), to: format_bound(bounds[index])
    end
  end

  # Operator and values of the filter of a class, see CLASS_BOUND_GAP
  def class_filter(index)
    bounds = class_bounds
    below = ->(bound) { filter_bound(integer_column?(group_column) ? bound - 1 : bound - CLASS_BOUND_GAP) }
    if index.zero?
      ['<=', [below.call(bounds.first)]]
    elsif index == bounds.size
      ['>=', [filter_bound(bounds.last)]]
    else
      ['><', [filter_bound(bounds[index - 1]), below.call(bounds[index])]]
    end
  end

  def format_bound(bound)
    ActiveSupport::NumberHelper.number_to_rounded bound, precision: 2, strip_insignificant_zeros: true,
                                                         locale: ::I18n.locale
  end

  # Plain decimals, a filter does not read 1.0e-06
  def filter_bound(bound)
    bound == bound.to_i ? bound.to_i.to_s : format('%.6f', bound).sub(/0+\z/, '')
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
    return unless timeline? && limited_timeline?
    return if group_column.is_a? QueryCustomFieldColumn

    sql = group_sql query.base_scope.klass, group_statement(query, group_column)
    days = query.base_scope.pick Arel.sql(sql).minimum, Arel.sql(sql).maximum
    return unless days&.last

    days = days.map { |day| user_zone_hours? ? user_day(day) : day.to_date }
    first = timeline_end days.last
    (max_periods(first) - 1).times { first = period_start first - 1 }
    # The periods before the first entry stay out like without the limit
    first = [first, period_start(days.first)].max
    periods_start[query] = first
    query.extend PeriodsScope
    query.periods_condition = periods_condition sql, first
  end

  # The first day as the column holds it. A timestamp of a user with a time
  # zone of their own begins at midnight of the user: the instant is quoted
  # in the time Redmine stores, no conversion by the database.
  def periods_condition(sql, first)
    return Arel.sql(sql).gteq(first) unless user_zone_hours?

    column = Arel.sql Array(group_column.sortable).first
    column.gteq User.current.time_zone.local(first.year, first.month, first.day)
  end

  # First period each query counts from, see limit_to_latest_periods
  def periods_start
    @periods_start ||= {}.compare_by_identity
  end

  def limited_timeline?
    calendar? || settings[:max_entries].to_i.positive?
  end

  # Maximum of periods a timeline up to its last day shows, nil for all of
  # them. A calendar starts with the first day of a week.
  def max_periods(last)
    return ((CALENDAR_WEEKS - 1) * 7) + ((last.cwday - first_wday) % 7) + 1 if calendar?

    max_entries = settings[:max_entries].to_i
    [max_entries, MAX_PERIODS].min if max_entries.positive?
  end

  # Days as cells of a calendar: a column per week, a row per weekday from
  # the first day of a week on. The levels of the colors are quantiles of
  # the days with values, so a calendar uses all its colors whatever the
  # numbers are, and a single large day does not pale all others.
  def calendar_payload
    offset = (entries.first.key.cwday - first_wday) % 7
    cells = entries.each_with_index.map { |entry, index| [entry, index + offset] }
    { points: cells.map { |entry, cell| { x: cell / 7, y: cell % 7, v: entry.value } },
      weeks: (cells.last.last / 7) + 1,
      weekdays: (0..6).map { |day| l('date.abbr_day_names')[(first_wday + day) % 7] },
      months: calendar_months(cells),
      levels: calendar_levels,
      legend: calendar_legend }
  end

  # The value of each level: none, up to each bound, above the last one
  def calendar_legend
    levels = calendar_levels
    texts = ['0'] + levels.map { |bound| l :label_chart_level_up_to, value: format_bound(bound) }
    texts << l(:label_chart_level_above, value: format_bound(levels.last)) if levels.any?
    texts
  end

  # Abbreviated month at the column of its first day, and at the first column.
  # Which of them fit next to each other only the width of the chart tells.
  def calendar_months(cells)
    cells.each_with_object({}) do |(entry, cell), months|
      next unless cell == cells.first.last || entry.key.day == 1

      months[cell / 7] = l('date.abbr_month_names')[entry.key.month]
    end
  end

  def calendar_levels
    @calendar_levels ||= begin
      values = entries.map(&:value).select(&:positive?).sort!
      values.empty? ? [] : CALENDAR_QUANTILES.map { |quantile| values[((values.size - 1) * quantile).floor] }.tap(&:uniq!)
    end
  end

  # All periods from the first to the last one, the latest ones up to the
  # maximum. Without entries before or after, a timeline would only start
  # or end later, so it shows the periods with entries.
  def timeline_periods(keys)
    first, last = timeline_bounds keys
    return [] unless last

    limit = max_periods(last) || MAX_PERIODS
    periods = [last]
    while periods.size < limit
      previous = period_start periods.last - 1
      break if previous < first

      periods << previous
    end
    periods.reverse
  end

  # First and last day of a timeline: of a fixed period, with its periods
  # without entries, otherwise of the entries
  def timeline_bounds(keys)
    if fixed_period?
      from, to = fixed_range
      return [period_start(from), period_start(to)]
    end

    first, last = keys.minmax
    return [] unless last

    # Periods without entries at the start of the limited ones show, too
    [[first, *periods_start.values].min, timeline_end(last)]
  end

  # Period the timeline ends with. Dates in the past only, e.g. created or
  # spent on, run up to today: weeks without entries since then are part of
  # what it shows. Other dates end with their last entry, they may lie in
  # the future.
  def timeline_end(last_day)
    return period_start last_day unless filter_type_for(group_column) == :date_past

    period_start [last_day, User.current.today].max
  end

  # The period restricts the query of the block and a compared query alike,
  # the previous period its own copy of the query. Applied once, when the
  # chart counts, since the period depends on the group column.
  def apply_periods
    return if @periods_applied

    @periods_applied = true
    return unless period

    return restrict_timelines if timeline?

    restrict_to_period query, period_filter
    return unless compare_query

    restrict_to_period compare_query, previous_period? ? ['><', previous_period_range.map(&:to_s)] : period_filter
  end

  # A day of the settings as the date fields send it, nil for none or another format
  def setting_date(key)
    value = settings[key].to_s
    Date.iso8601 value if value.match? Additionals::SettingsSchema::DATE_FORMAT
  rescue Date::Error
    nil
  end

  # A relative period as the date filters of core name it, a fixed one by its days
  def period_filter
    fixed_period? ? ['><', fixed_range.map(&:to_s)] : [period, ['']]
  end

  # A fixed period bounds the date of a timeline in each query; the links of
  # its periods filter their days themselves
  def restrict_timelines
    filter = filter_name_for group_column
    return unless filter

    [query, compare_query].compact.each do |series_query|
      series_query.extend DatePeriodScope
      series_query.period_statement = query_class.new(name: '_', filters: { filter => { operator: '><', values: fixed_range.map(&:to_s) } })
                                                 .statement
    end
  end

  def restrict_to_period(query, period_filter)
    return unless query

    operator, values = period_filter
    query.extend DatePeriodScope
    query.period_filter = period_filter
    query.period_statement = query_class.new(name: '_', filters: { period_field => { operator:, values: } }).statement
  end

  # First and last day of a period as the date filters of core count it,
  # weeks starting like they do with the first day of the language
  def period_range(code)
    return fixed_range code if FIXED_PERIOD_LABELS.key? code

    today = User.current.today
    case code
    when 'w', 'lw'
      start = today - ((today.cwday - l(:general_first_day_of_week).to_i) % 7)
      start -= 7 if code == 'lw'
      [start, start + 6]
    when 'm' then [today.beginning_of_month, today.end_of_month]
    when 'lm' then [today.prev_month.beginning_of_month, today.prev_month.end_of_month]
    else [today.beginning_of_year, today.end_of_year]
    end
  end

  def previous_period_labels
    ranges = [period_range(period), previous_period_range]
    return ranges.map { |from, to| l :label_date_from_to, start: format_date(from), end: format_date(to) } if fixed_period?

    ranges.map { |range| period_label range.first, PERIODS[period] }
  end

  # As many days right before a fixed period
  def previous_period_range
    from, to = period_range period
    return [from - (to - from + 1), from - 1] if fixed_period?

    case PERIODS[period]
    when 'week' then [from - 7, to - 7]
    when 'month' then [from.prev_month.beginning_of_month, from.prev_month.end_of_month]
    else [from.prev_year, to.prev_year]
    end
  end

  # Days of a period for the filter of its link. A filter of the query on the
  # same date would be replaced by it, so the days with entries keep its
  # bounds: a date filter always covers one range of days. Outside of them,
  # e.g. a period only the compared query has, nothing is left to link to.
  def period_filter_values(query, start)
    from = start
    to = period_end start
    if fixed_period?
      from = [from, fixed_range.first].max
      to = [to, fixed_range.last].min
    end
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
    counts = if number_classes? && !multiple_values_column?(split_column)
               number_split_counts query
             elsif multiple_values_column?(group_column) || multiple_values_column?(split_column)
               multiple_split_counts query
             else
               split_counts query
             end
    counts = to_user_days counts if user_zone_hours?
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
    other_sql = Arel.sql split_group(klass, other, statement)
    value = CustomValue.arel_table[:value]

    # Plucked, see number_values
    counts = with_values.joins(query_joins(query, [statement]))
                        .group(other_sql, value).pluck(other_sql, value, distinct_count(with_values))
                        .to_h { |other_key, field_value, count| [[other_key, field_value], count] }
    without = query.base_scope.where.not(id: with_values.select(:id)).joins(query_joins(query, [statement]))
    without.group(other_sql).pluck(other_sql, distinct_count(without))
           .each { |other_key, count| counts[[other_key, nil]] = count }

    # Keys as [group, split]
    counts = map_split_keys klass, counts, [[other, statement], [multiple, nil]]
    return counts if other == group_column

    counts.transform_keys(&:reverse)
  end

  # Statement of a column as the query groups by it. A query class may
  # decide that itself, e.g. for columns of its own. Core groups by no number
  # columns but those of custom fields, the base groups by the column then.
  def group_statement(query, column)
    return number_statement column if number_type? column
    return hour_statement column if column == group_column && user_zone_hours?

    core_group_statement query, column
  end

  # The query keeps the grouping it had
  def core_group_statement(query, column)
    group_by = query.group_by
    query.group_by = column.name.to_s
    query.group_by_statement
  ensure
    query.group_by = group_by
  end

  # Timestamps are stored in the time of the server (or UTC). Grouped by the
  # day of a user with a time zone of their own, the database would have to
  # convert them: MySQL can only with its time zone tables loaded, PostgreSQL
  # in the time zone of its session. A plugin can rely on neither, so the
  # database counts per hour as stored and Ruby moves each hour to the day of
  # the user. Without a time zone of the user core groups as before.
  # Core converts with CONVERT_TZ from Time.zone since
  # https://www.redmine.org/issues/32046, which needs the time zone tables of
  # MySQL and ignores that Redmine stores in the time of the server. Once core
  # groups timestamps independent of the database, the core grouping
  # (group_by_statement) can be used again here.
  def user_zone_hours?
    return @user_zone_hours if defined? @user_zone_hours

    @user_zone_hours = timeline? && group_column.is_a?(TimestampQueryColumn) && User.current.time_zone.present?
  end

  def hour_statement(column)
    stored_hour_sql Array(column.sortable).first
  end

  # Values per hour as stored, counted like core counts a group
  def user_zone_values(query)
    statement = Arel.sql hour_statement(group_column)
    scope = query.base_scope.group statement
    values = measure_column ? query.send(:total_with_scope, measure_column, scope) : scope.distinct.count(:id)
    to_user_days values
  end

  # Hours as stored summed up to the days of the user, also as the first part
  # of the keys of a split
  def to_user_days(values)
    values.each_with_object({}) do |(key, value), days|
      day = key.is_a?(Array) ? [user_day(key.first), *key.drop(1)] : user_day(key)
      days[day] = days.key?(day) ? days[day] + value : value
    end
  end

  def user_day(hour)
    User.current.time_to_date stored_hour(hour) if hour.present?
  end

  def number_statement(column)
    column.is_a?(QueryCustomFieldColumn) ? column.custom_field.group_statement : column.name.to_s
  end

  # Joins the statements need, e.g. the values of a custom field
  def query_joins(query, statements)
    query.send :joins_for_order_statement, statements.join(',')
  end

  # A number groups by its class, any other column by its statement
  def split_group(klass, column, statement)
    number_classes? && column == group_column ? class_expression(klass, column) : group_sql(klass, statement)
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
    if number_classes? && column == group_column
      keys.index_with { |key| key&.to_i }
    elsif column.is_a? QueryCustomFieldColumn
      cast_custom_values column.custom_field, keys
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
    return number_values query if number_classes?
    return user_zone_values query if user_zone_hours?

    values = measure_column ? query.total_by_group_for(measure_column) : query.result_count_by_group
    merge_blank_keys values || {}
  end

  # Values per class, the index of the class as key. The database groups by
  # class, so sums are rounded per class like the totals of the list.
  # ActiveRecord names the key of a grouping after its expression and cannot
  # read it back once the name is cut, as for the long expression of a
  # custom field: counts are plucked, sums taken class by class.
  def number_values(query)
    scope = number_scope query
    expression = class_expression scope.klass, group_column
    if measure_column
      return class_keys.index_with do |index|
        query.send :total_with_scope, measure_column, scope.where(class_condition(expression, index))
      end
    end

    scope.group(expression).pluck(expression, distinct_count(scope)).to_h { |index, count| [index&.to_i, count] }
  end

  # Values per class and value of the split column, see number_values
  def number_split_counts(query)
    statement = group_statement query, split_column
    scope = number_scope(query).joins query_joins(query, [statement])
    expression = class_expression scope.klass, group_column
    other = Arel.sql group_sql(scope.klass, statement)
    counts = if measure_column
               class_keys.each_with_object({}) do |index, values|
                 grouped = scope.where(class_condition(expression, index)).group(other)
                 query.send(:total_with_scope, measure_column, grouped).each { |key, value| values[[index, key]] = value }
               end
             else
               scope.group(expression, other).pluck(expression, other, distinct_count(scope))
                    .to_h { |index, key, count| [[index&.to_i, key], count] }
             end
    map_split_keys scope.klass, counts, [[group_column, nil], [split_column, statement]]
  end

  def distinct_count(scope)
    scope.klass.arel_table[:id].count true
  end

  # Every class and no value. Without any value there are no bounds to
  # build classes from, only entries without one.
  def class_keys
    (class_bounds.any? ? (0..class_bounds.size).to_a : []) << nil
  end

  def class_condition(expression, index)
    index.nil? ? expression.eq(nil) : expression.eq(index)
  end

  def number_scope(query)
    query.base_scope.joins query_joins(query, [number_statement(group_column)])
  end

  # The number of a column as the database compares it
  def number_expression(klass, column)
    return Arel::Table.new(klass.table_name)[column.name] unless column.is_a? QueryCustomFieldColumn

    Arel.sql column.custom_field.order_statement
  end

  # NULL, and an empty value of a custom field, which the number would read as 0
  def no_number_condition(klass, column)
    return Arel::Table.new(klass.table_name)[column.name].eq(nil) unless column.is_a? QueryCustomFieldColumn

    value = Arel::Table.new("cf_#{column.custom_field.id}")[:value]
    value.eq(nil).or(value.eq(''))
  end

  # Index of the class of a number, NULL without one. Built by Arel, handed
  # over as SQL: grouped by a node, ActiveRecord cannot read back the keys.
  def class_expression(klass, column)
    number = number_expression klass, column
    expression = Arel::Nodes::Case.new.when(no_number_condition(klass, column)).then(Arel.sql('NULL'))
    class_bounds.each_with_index { |bound, index| expression = expression.when(number.lt(bound)).then(index) }
    Arel.sql expression.else(class_bounds.size).to_sql
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
    counts.transform_keys! cast_custom_values(custom_field, counts.keys)
    without = query.base_scope.where.not(id: with_values.select(:id)).distinct.count(:id)
    counts[nil] = without if without.positive?
    counts
  end

  # Values of a custom field as core casts them, the records of a list of
  # records (users, versions, ...) in one query instead of one per value
  def cast_custom_values(custom_field, values)
    format = custom_field.format
    unless format.is_a?(Redmine::FieldFormat::RecordList) && format.target_class
      return values.index_with { |value| value.presence && custom_field.cast_value(value) }
    end

    records = format.target_class.where(id: values.compact_blank.map(&:to_i)).index_by(&:id)
    values.index_with { |value| value.presence && records[value.to_i] }
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
    apply_periods
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
    return class_label key if column == group_column && number_classes?
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
      elsif number_classes? && filter == key_filters.keys.first
        add_url_filter params, filter, *class_filter(filter_key)
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
    period_filter = query.try :period_filter
    if period_filter
      # A date filter of the query and the period cannot be joined into one
      own = filters[period_field]
      return if own && own.first != '*'

      filters[period_field] = period_filter
    end
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
