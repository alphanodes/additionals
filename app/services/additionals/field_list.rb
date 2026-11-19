# frozen_string_literal: true

module Additionals
  # Base of a list macro: collects records by their values and renders one line
  # per record with a FieldTemplate.
  #
  # A subclass decides which records there are and how they are filtered; this
  # class reads the arguments, sorts, enforces the limit and keeps the numbers
  # a template brings of its own. The result is wiki text, not HTML: the caller
  # runs it through the formatter, so a template may use wiki syntax and
  # macros. Only a list whose lines bring numbers of their own is touched again
  # afterwards, by mark_list - the list element is built by the formatter and
  # can be labelled nowhere else.
  #
  # A subclass calls super first, which reads the arguments into @options and
  # @filters, and implements the private hooks below which raise
  # NotImplementedError here.
  #
  # The template of a line is, in this order: the block of the macro, the
  # block of the wiki page named by template=PAGE (see FieldTemplateBlock),
  # the default_template of the subclass.
  class FieldList
    MAX_ENTRIES = 500
    # how deep a line may hold a list again, the outermost one counted
    MAX_NESTING = 3
    # a list item and its mark, in markdown as html and in textile as a span
    # of its own - textile escapes html
    MARKDOWN_ITEM = '- <span>%<mark>s </span>%<text>s'
    TEXTILE_ITEM = '* %%%<mark>s%% %<text>s'
    # ASCII punctuation, which textile only leaves alone as a numeric entity
    PUNCTUATION_RE = /[!-\/:-@\[-`{-~]/
    MARK_LIST_CLASS = 'additionals-list-marks'
    MARK_LIST_TYPE = 'none'
    MARK_WIDTH_PROPERTY = '--a-list-mark-width'
    # an argument asks for an empty or a filled field the way a template
    # condition does
    BLANK_FILTER = FieldTemplate::BLANK_CONDITION
    PRESENT_FILTER = FieldTemplate::PRESENT_CONDITION
    # The name of an argument, its operator and its value. The longer
    # operators come first, so "!=" is not read as a name ending in "!".
    ARGUMENT_RE = /\A([^=!~]*?)\s*(!=|!~|=|~)(.*)\z/m
    OPTION_OPERATOR = '='
    # an option of every list, so a template is kept once for many pages
    TEMPLATE_OPTION = 'template'
    VALUE_SEPARATOR = '|'
    DESCENDING_PREFIX = '-'
    # Where a line needs no hard break, or where markdown would print its
    # backslash: an item of a list, a heading, a line of html
    NO_HARD_BREAK_RE = /\A\s*(?:(?:[-*+]|\d+[.)])\s|#|<)/
    # the formats whose text "~" can look into
    TEXT_FORMATS = %w[string text].freeze

    # A filter argument: the field it names, its operator and the values it
    # accepts, any of which is enough.
    Filter = Struct.new :name, :operator, :accepted do
      def negated?
        operator.start_with? '!'
      end

      def contains?
        operator.end_with? '~'
      end
    end

    class Error < Additionals::LocalizedError; end

    # The page of template=PAGE does not exist or the reader may not see it.
    # Both end in the same notice, so the list gives away neither.
    class NotAvailable < StandardError; end

    # How wide the column of the marks has to be, in characters of the longest
    # one. Taken from the records which are listed, so a list of "9." to "12a."
    # does not reserve the room a three digit one needs.
    attr_reader :mark_width

    # How many lines the list rendered, known after to_wiki_text
    attr_reader :line_count

    # block_template is the text of the macro block, project the one a page
    # name without a project of its own belongs to.
    def initialize(args, block_template = nil, project: nil)
      @block_template = block_template
      @project = project
      parse_args args
    end

    # The wiki page the template comes from, nil where the macro brings one of
    # its own or names none. Asked before rendering, so the caller can keep a
    # template page from listing itself.
    def template_page
      return if @block_template.present? || @options[TEMPLATE_OPTION].blank?

      @template_page ||= find_visible_page @options[TEMPLATE_OPTION]
    end

    # limit is what is left of the records a list and the lists in its lines
    # may render together, see render_field_list
    def to_wiki_text(limit: MAX_ENTRIES)
      @marked = renderer.marked? template
      # an unknown sort field is reported whether or not there are records
      sort_field
      # a template without a mark answers with the whole line, so both kinds
      # of list are rendered the same way and only put together differently
      records = checked_records(limit).to_a
      renderer.preload_references records, template, [sort_field].compact
      records = sorted records
      lines = records.map { |record| renderer.marked_line template, record }
      @line_count = lines.size
      return join_lines lines.map(&:text) unless @marked

      @mark_width = lines.filter_map { |line| line.mark&.length }.max

      lines.map { |line| list_item line }.join "\n"
    end

    # Whether the lines carry a mark of their own, which the caller has to
    # keep the formatter away from. Answered after the text was rendered,
    # because the template decides it.
    def marked?
      @marked.present?
    end

    # Tells the rendered list that it brings its own marks. The lines went
    # through the formatter, so the list element is built by it and can only
    # be labelled afterwards - which is also where the sanitizer no longer
    # strips what is added. "type=none" is the one spelling which keeps
    # chromium, firefox and the pdf export from drawing a marker of their own;
    # a class alone would leave a bullet in front of every number in the pdf.
    def mark_list(html)
      fragment = Nokogiri::HTML5.fragment html.to_s
      lists = fragment.children.select { |node| node.name == 'ul' }
      return html if lists.empty?

      lists.each do |list|
        list['type'] = MARK_LIST_TYPE
        list['class'] = MARK_LIST_CLASS
        list['style'] = "#{MARK_WIDTH_PROPERTY}: #{mark_width}ch" if mark_width.to_i.positive?
      end

      # The fragment is the sanitized output of the formatter, and what was
      # added to it are three attributes built here, none of them from a value
      # of a record - there is nothing left to escape.
      fragment.to_html.html_safe # rubocop:disable Rails/OutputSafety
    end

    private

    # The options this list understands, in downcase. Every other argument is
    # a filter.
    def reserved_options
      raise NotImplementedError, "#{self.class.name} has to name its options"
    end

    # The visible records, narrowed down by the filters
    def records
      raise NotImplementedError, "#{self.class.name} has to select its records"
    end

    # The template of a line without a block and without template=PAGE
    def default_template
      raise NotImplementedError, "#{self.class.name} has to name its default template"
    end

    # The language of the code block which holds the template on a wiki page,
    # the name of the macro
    def block_language
      raise NotImplementedError, "#{self.class.name} has to name the language of its template block"
    end

    # The FieldTemplate which renders a line, with escape_macros: true
    def renderer
      raise NotImplementedError, "#{self.class.name} has to build its renderer"
    end

    # The custom fields an argument may name
    def available_fields
      raise NotImplementedError, "#{self.class.name} has to name its fields"
    end

    # What a record is sorted by without the sort option
    def default_sort_value(_record)
      raise NotImplementedError, "#{self.class.name} has to name its default order"
    end

    # Attributes the sort option may name besides the custom fields, as name
    # and a callable which reads the value of a record.
    def sort_attributes
      {}
    end

    # The field of the sort option, nil without one or where it names an
    # attribute. Read once, so an unknown field is reported however often the
    # list asks for it.
    def sort_field
      return @sort_field if defined? @sort_field

      name = sort_name
      @sort_field = (find_field name, 'sort' if name.present? && !sort_attributes.key?(name.downcase))
    end

    def template
      @template ||= @block_template.presence || page_template || default_template
    end

    def page_template
      page = template_page
      return if page.nil?

      FieldTemplateBlock.find(page.content.text, block_language) ||
        raise(Error.new(:error_field_template_block_missing, page: page.pretty_title, language: block_language))
    end

    # Resolved like a wiki link of core: "Page" in the wiki of the project,
    # "project:Page" in another one.
    def find_visible_page(name)
      page = Wiki.find_page name, project: @project
      raise NotAvailable if page.nil? || !page.visible?

      page
    end

    def sort_name
      @options['sort'].to_s.delete_prefix DESCENDING_PREFIX
    end

    def descending?
      @options['sort'].to_s.start_with? DESCENDING_PREFIX
    end

    # Options go to @options, every other argument is a filter in @filters.
    # Both are matched by name, so an option keeps a custom field of the same
    # name from being filtered. An option knows no operator but "=", and a
    # field may be asked once only - a second argument would otherwise quietly
    # replace the first.
    def parse_args(args)
      @options = {}
      @filters = []

      Array(args).each do |arg|
        name, operator, value = read_argument arg
        if option? name
          raise Error.new(:error_field_list_operator_not_supported, operator:, name:) unless operator == OPTION_OPERATOR
          raise Error.new(:error_field_list_duplicate_argument, argument: arg) if @options.key? name.downcase
          raise Error.new(:error_field_list_argument_without_value, argument: arg) if value.empty?

          @options[name.downcase] = value
        else
          raise Error.new(:error_field_list_duplicate_argument, argument: arg) if @filters.any? { |filter| filter.name.casecmp? name }

          @filters << Filter.new(name, operator, filter_values(arg, value))
        end
      end
    end

    def option?(name)
      key = name.downcase
      key == TEMPLATE_OPTION || reserved_options.include?(key)
    end

    # An empty value could never be meant - "Field=" or "Field=A|" would only
    # leave the list empty or lose a part of it without a word.
    def filter_values(arg, value)
      values = value.split(VALUE_SEPARATOR, -1).map(&:strip)
      raise Error.new(:error_field_list_argument_without_value, argument: arg) if values.empty? || values.any?(&:empty?)

      values
    end

    def read_argument(arg)
      match = ARGUMENT_RE.match arg.to_s.strip
      raise Error.new(:error_field_list_argument_without_value, argument: arg) if match.nil?

      [match[1].strip, match[2], match[3].strip]
    end

    # Narrows the records down to those whose custom field carries one of the
    # values of the filter, or none of them where it is negated. Compared
    # without regard to case, the way a template condition reads a value.
    def filter_by_custom_field(scope, field, filter)
      if filter.contains? && TEXT_FORMATS.exclude?(field.field_format)
        raise Error.new(:error_field_list_operator_not_supported, operator: filter.operator, name: filter.name)
      end

      values = CustomValue.where customized_type: scope.klass.base_class.name, custom_field_id: field.id
      filled = values.where.not(value: [nil, '']).select(:customized_id)

      apply_filter scope, filter, filled do |value|
        values.where(like_value('custom_values.value', value, filter)).select(:customized_id)
      end
    end

    # The frame of every filter, whatever it reads: "none" is met by the
    # records outside of filled, "any" by those in it, every other value by
    # the ids the block selects for it. The values are alternatives, and a
    # negated filter keeps the records which meet none of them - including
    # those without a value, which do not carry the one asked for either.
    def apply_filter(scope, filter, filled)
      ids = scope.klass.arel_table[:id]
      nodes = filter.accepted.map do |value|
        if keyword? value, BLANK_FILTER
          ids.not_in filled.arel
        elsif keyword? value, PRESENT_FILTER
          ids.in filled.arel
        else
          ids.in yield(value).arel
        end
      end
      condition = Arel::Nodes::Grouping.new(nodes.reduce { |all, node| all.or node })

      scope.where filter.negated? ? condition.not : condition
    end

    # A condition on a text column, the whole value or a part of it
    def like_value(column, value, filter)
      pattern = ActiveRecord::Base.sanitize_sql_like value
      pattern = "%#{pattern}%" if filter.contains?

      [Redmine::Database.like(column, '?'), pattern]
    end

    # A shortened list would silently claim to be complete, and shortening it
    # meaningfully would need sorting in sql plus an offset. Whoever hits this
    # has to narrow the list down instead.
    def checked_records(limit)
      scope = records
      raise Error.new(:error_field_list_too_many_entries, count: MAX_ENTRIES) if scope.count > limit

      scope
    end

    # A field is named like in a template: by its name in any case or as
    # cf_ID.
    def find_field(name, argument)
      id = name[FieldTemplate::CUSTOM_FIELD_RE, 1]
      field = if id
                available_fields.detect { |custom_field| custom_field.id == id.to_i }
              else
                available_fields.detect { |custom_field| custom_field.name.casecmp? name }
              end
      raise Error.new(:error_field_list_unknown_field, argument: argument, name: name) if field.nil?

      field
    end

    def keyword?(value, keyword)
      value.is_a?(String) && value.casecmp(keyword).zero?
    end

    # A line of a marked list, as an item whose mark is an element instead of
    # a list marker. Written that way because markdown reads "38. " as the
    # start of an ordered list and then counts on its own, which loses every
    # number but the first. A record without a number keeps the empty element,
    # so its text stays in line with the others.
    #
    # The space belongs inside the element: a browser drops it at the end of
    # the column and takes the distance from the stylesheet, while the pdf
    # export and a page without the stylesheet keep it and stay readable.
    def list_item(line)
      if Setting.text_formatting == FieldTemplateBlock::COMMON_MARK
        format MARKDOWN_ITEM, mark: ERB::Util.html_escape(line.mark), text: line.text
      else
        # an empty span is no span in textile, a line without a mark keeps its
        # column with a space
        mark = line.mark.present? ? line.mark.gsub(PUNCTUATION_RE) { |char| "&##{char.ord};" } : '&#160;'
        format TEXTILE_ITEM, mark:, text: line.text
      end
    end

    # Lines are joined by a line break, which markdown reads as a space: a
    # line which is no item of a list gets a hard break, so it stays a line of
    # its own. Textile turns every line break into one already.
    def join_lines(texts)
      return texts.join "\n" unless Setting.text_formatting == 'common_mark'

      last = texts.size - 1
      texts.each_with_index.map { |text, index| hard_break?(text, index == last) ? "#{text}\\" : text }
           .join "\n"
    end

    def hard_break?(text, last)
      !last && text.present? && !text.match?(NO_HARD_BREAK_RE)
    end

    # Records without a sort value go last, also in a descending order, so a
    # record which has no number yet does not jump to the top of the list.
    # Records of the same value, and those without one, keep the default
    # order among each other, in both directions.
    # Without sort= by the default value, read like any text: naturally and
    # without regard to case, so "Part 2" comes before "Part 10".
    def sorted(records)
      return records.sort_by { |record| default_sort_key record } if @options['sort'].blank?

      filled, empty = records.map { |record| [record, sort_value(record)] }.partition { |_record, value| value.present? }
      keyed = filled.map { |record, value| [record, sort_key(value), default_sort_key(record)] }
      keyed.sort! do |(_, key_a, default_a), (_, key_b, default_b)|
        order = descending? ? key_b <=> key_a : key_a <=> key_b
        order.zero? ? (default_a <=> default_b).to_i : order
      end

      keyed.map(&:first) + empty.map(&:first).sort_by { |record| default_sort_key record }
    end

    def default_sort_key(record)
      natural_sort_key default_sort_value(record).to_s
    end

    # A field which references records (a user, a wiki page, ...) stores ids,
    # which say nothing about the order a reader expects: it is sorted by
    # what the line shows.
    def sort_value(record)
      attribute = sort_attributes[sort_name.downcase]
      return attribute.call record if attribute
      return renderer.field_text record, sort_field if reference_sort_field?

      Array(record.custom_field_value(sort_field.id)).compact_blank
    end

    def reference_sort_field?
      sort_field.format.is_a?(Redmine::FieldFormat::RecordList) && sort_field.field_format != 'enumeration'
    end

    # A number field is compared as a number, a list field by the order of its
    # values and a key/value field by the position of its entries - the order
    # whoever defined them meant, which the alphabet is not. Every other value
    # is compared in its digit and its text parts: "2" belongs in front of
    # "10", and an item numbered "12a" between "12" and "13" - which a plain
    # string comparison gets wrong. Each part becomes a triple of the same
    # types, otherwise a digit part would end up being compared with a text
    # part.
    def sort_key(value)
      # a string answers to_time as well, so the type is asked
      return [[0, value.to_time.to_f, '']] if value.is_a?(Date) || value.is_a?(Time)
      return [[0, value.to_f, '']] if value.is_a? Numeric
      return natural_sort_key value.to_s unless value.is_a? Array

      case sort_field.field_format
      when 'int', 'float' then [[0, value.first.to_f, '']]
      when 'list', 'enumeration' then [[0, value.map { |single| value_position single }.min, '']]
      else natural_sort_key value.join(', ')
      end
    end

    def natural_sort_key(text)
      text.downcase.scan(/\d+|\D+/).map do |part|
        part.match?(/\A\d/) ? [0, part.to_i, ''] : [1, 0, part]
      end
    end

    # A value which is no longer offered goes behind the offered ones
    def value_position(value)
      @value_positions ||= if sort_field.field_format == 'enumeration'
                             sort_field.enumerations.to_h { |entry| [entry.id.to_s, entry.position] }
                           else
                             sort_field.possible_values.each_with_index.to_h
                           end
      @value_positions.fetch value, @value_positions.size
    end
  end
end
