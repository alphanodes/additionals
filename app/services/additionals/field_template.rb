# frozen_string_literal: true

module Additionals
  # Renders a template with the values of a record: its custom fields and the
  # attributes its source offers.
  #
  # The form of a template - where a placeholder begins and where an optional
  # part ends - belongs to FieldTemplateParser. What a name means beyond a
  # custom field is up to the source (see FieldTemplateSource), so the same
  # language serves every kind of record. The result is plain text: whether it
  # ends up as wiki text or as a value of the record itself is up to the
  # caller.
  class FieldTemplate
    include Redmine::I18n

    # What a part of the template rendered, and what it contributes to the part
    # around it: a condition which is met or not, a value which is there or not.
    # A part which fell away contributes nothing, so it cannot keep the one
    # around it alive.
    Rendered = Struct.new :text, :parts
    Part = Struct.new :condition, :present
    # A rendered line of a list, split into the mark it begins with and the
    # rest: "38." and "North ridge". The mark is nil where the template
    # carries none, and where it carries one which this record leaves empty.
    Line = Struct.new :mark, :text

    JOIN_FUNCTION = 'join'
    CONDITION_PREFIX = '?'
    # A condition names its field, an operator and the values it asks for:
    # {%?Field!=A|B%}. The longer operators come first, so "!=" is not read
    # as a name ending in "!".
    CONDITION_RE = /\A([^=!~]*?)(!=|!~|=|~)(.*)\z/m
    VALUE_SEPARATOR = '|'
    # The value which asks for a field to be empty. A list names the same thing
    # the same way in its arguments, and one word for one question is worth
    # more than the rare list value which is called "none" and can no longer
    # be asked for by name.
    BLANK_CONDITION = 'none'
    # Its counterpart. {%?Field%} asks the same thing in short, but the
    # arguments of a list know "any", and whoever learned it there writes it in
    # a condition sooner or later - where it would look for a field carrying
    # the value "any" and quietly never be true.
    PRESENT_CONDITION = 'any'
    CUSTOM_FIELD_RE = /\Acf_(\d+)\z/i
    # What separates a mark from the line behind it, followed by a space: the
    # two characters markdown reads as a list marker. Whoever writes
    # "{%Number%}. " means the number of the record to be the mark of the line -
    # and exactly there the formatter would replace it with a count of its own.
    MARK_RE = /\A([.)])[ \t]+/
    # the same, but as the whole text of an optional part: "[{%Number%}. ]"
    MARK_ONLY_RE = /\A([.)])[ \t]*\z/

    class Error < Additionals::LocalizedError; end

    # escape_macros is for templates whose result is rendered as wiki text: a
    # macro call stored in a field would otherwise be executed with the rights
    # of whoever reads the page, and a self reference would recurse. strict is
    # for checking a template before it is saved (see FieldTemplateParser).
    def initialize(source, escape_macros: false, strict: false)
      @source = source
      @escape_macros = escape_macros
      @strict = strict
    end

    # Checks what a template has to get right whatever it is rendered with:
    # its brackets, its conditions and its functions. Whether a placeholder
    # names a field is left to rendering, where the fields are known. Meant
    # for a template about to be saved, so it is read strictly.
    def self.check_syntax(template)
      new(FieldTemplateSource.new, strict: true).check_syntax template
    end

    def check_syntax(template)
      tree template
      nil
    end

    # The printed value of a custom field, as a template prints it
    def field_text(record, field)
      custom_field_value record, field
    end

    # A field which references records (a user, a version, a wiki page, ...)
    # loads each of them on its own when a value is read, which is one query
    # per line of a list. Loaded here once per field for all records instead.
    # fields are further fields to load, the field a list is sorted by. An id
    # whose record is gone (a deleted user) is remembered as missing, so it is
    # not looked up once more for every line.
    def preload_references(records, template, fields = [])
      @references = (referenced_fields(template) | fields.select { |field| reference_class field }).to_h do |field|
        ids = records.flat_map { |record| Array record.custom_field_value(field.id) }
        ids = ids.filter_map { |id| id.presence&.to_i }
        ids.uniq!
        found = reference_class(field).where(id: ids).index_by(&:id)
        [field.id, ids.index_with { |id| found[id] }]
      end
    end

    def render(template, record)
      render_nodes(tree(template), record).text
    end

    # Renders a line of a list and keeps its mark separate, so the caller can
    # put the mark where the formatter cannot count it away. A template which
    # does not begin with a mark of its own answers with the whole line and no
    # mark.
    def marked_line(template, record)
      mark_nodes, rest_nodes = mark_split template
      return Line.new nil, render(template, record) if mark_nodes.nil?

      mark = render_nodes(mark_nodes, record).text
      mark.strip!

      Line.new mark.presence, render_nodes(rest_nodes, record).text
    end

    # Whether a template puts a mark of its own in front of every line. Read
    # from the template, not from the rendered text: only here is it certain
    # that the mark comes from a placeholder and is therefore a number of the
    # record, not a "1." somebody wrote down to have the list counted.
    def marked?(template)
      !mark_split(template).nil?
    end

    # The fields a template is built from, by their labels and in the order
    # they appear. Lets a message name what makes up a value without showing
    # the template itself, which would tell a user nothing.
    def field_labels(template)
      labels = FieldTemplateParser.placeholder_names(template).map { |name| label_for field_name(name) }
      labels.compact!
      labels.uniq!
      labels
    end

    private

    # Splits the leading mark off a template, as two lists of nodes, or nil
    # where there is none to split. Read once per template like the tree
    # itself.
    #
    # Two spellings mean the same thing, and only these two: "{%Number%}. " and
    # the same wrapped in brackets, which drops the mark of a record without a
    # number. Anything else in front - a fixed "1. ", a "- ", a value - is left
    # alone, because only a placeholder can carry a number of the record.
    def mark_split(template)
      @mark_splits ||= {}
      return @mark_splits[template] if @mark_splits.key? template

      @mark_splits[template] = split_mark tree(template)
    end

    def split_mark(nodes)
      leading = nodes.first
      return grouped_mark nodes if leading.is_a? FieldTemplateParser::Group
      return unless mark_placeholder? leading

      separator = nodes[1]&.text.to_s[MARK_RE, 0]
      return if separator.nil?

      [[leading, FieldTemplateParser::Text.new(separator)],
       [FieldTemplateParser::Text.new(nodes[1].text.delete_prefix(separator)), *nodes.drop(2)]]
    end

    # An optional part is a mark when it holds nothing but the placeholder and
    # the separator: "[{%Number%}. {%Grade%}]" carries more than a mark and is
    # none.
    def grouped_mark(nodes)
      children = nodes.first.children
      return unless children.size == 2 && mark_placeholder?(children.first)
      return unless children.last.is_a?(FieldTemplateParser::Text) && children.last.text.match?(MARK_ONLY_RE)

      [[nodes.first], nodes.drop(1)]
    end

    # A condition prints nothing, so it can never be a mark.
    def mark_placeholder?(node)
      node.is_a?(FieldTemplateParser::Placeholder) && !node.name.start_with?(CONDITION_PREFIX)
    end

    # Read once per template: a list renders the same one for every record.
    def tree(template)
      @trees ||= {}
      @trees[template] ||= FieldTemplateParser.parse(template, strict: @strict).tap { |nodes| check_conditions nodes }
    end

    # Asked while the template is read and not while a value is resolved: a
    # broken condition has to be reported for every record, not only for those
    # whose field happens to be filled.
    def check_conditions(nodes)
      nodes.each do |node|
        case node
        when FieldTemplateParser::Placeholder then condition node.name
        when FieldTemplateParser::Function then check_function node
        when FieldTemplateParser::Group then check_conditions node.children
        end
      end
    end

    def render_nodes(nodes, record)
      rendered = nodes.map { |node| render_node node, record }

      Rendered.new rendered.map(&:text).join, rendered.flat_map(&:parts)
    end

    def render_node(node, record)
      case node
      when FieldTemplateParser::Text then Rendered.new node.text, []
      when FieldTemplateParser::Placeholder then render_placeholder node, record
      when FieldTemplateParser::Function then render_function node, record
      else render_group node, record
      end
    end

    def render_placeholder(node, record)
      part = Part.new node.name.start_with?(CONDITION_PREFIX), value_present?(record, node.name)

      Rendered.new printed_value(record, node.name), [part]
    end

    # join is the one function there is: it lines up the values which are
    # there and leaves out the separator of those which are not. Written as
    # {%join(", ", Field, Field)%}.
    def render_function(node, record)
      separator, names = check_function node
      values = names.map { |name| printed_value record, name }
      values.compact_blank!

      Rendered.new values.join(separator), [Part.new(false, values.any?)]
    end

    def check_function(node)
      raise Error.new(:error_field_template_unknown_function, name: node.source) unless node.name.casecmp? JOIN_FUNCTION

      join_arguments node
    end

    # The separator is the quoted first argument, every argument behind it
    # names a value. A template which does not say it that way is refused
    # instead of printing something nobody meant.
    def join_arguments(node)
      separator = node.arguments.first
      names = node.arguments.drop 1
      if separator.nil? || !separator.literal || names.none? || names.any?(&:literal)
        raise Error.new(:error_field_template_invalid_join, name: node.source)
      end

      [separator.value, names.map(&:value)]
    end

    def label_for(placeholder)
      label = @source.reserved_placeholders[placeholder.downcase]
      return label.is_a?(Symbol) ? l(label) : label if label

      field_for(placeholder)&.name
    end

    # Every name the source gives a meaning of its own. A custom field of the
    # same name can only be addressed by its id.
    def reserved?(placeholder)
      @source.reserved_placeholders.key? placeholder.downcase
    end

    def available_fields
      @available_fields ||= @source.custom_fields
    end

    # A field is addressed by its id (cf_42) or by its name. The id is what the
    # variable list inserts and what survives a rename, the name is what a
    # template written by hand inside a macro reads - there the fields are
    # named in the arguments as well.
    def field_for(placeholder)
      id = placeholder[CUSTOM_FIELD_RE, 1]
      return available_fields.detect { |custom_field| custom_field.id == id.to_i } if id

      available_fields.detect { |custom_field| custom_field.name.casecmp? placeholder }
    end

    def find_field(placeholder)
      field = field_for placeholder
      raise Error.new(:error_field_template_unknown_placeholder, name: placeholder) if field.nil?

      field
    end

    # Two kinds of placeholders, two rules: every condition has to be met, and
    # of the printing ones at least one has to carry a value. A condition is
    # not a source of a value - a filled field next to it must not outvote it,
    # which is what a reader of "[ {%?status=invalid%} {%cf_reason%}]"
    # expects. A group of conditions alone has nothing to be filled and stays
    # on its own.
    #
    # Brackets without any placeholder are left alone including the brackets
    # themselves, so a markdown link in the template survives.
    def render_group(node, record)
      inner = render_nodes node.children, record
      return Rendered.new "#{FieldTemplateParser::GROUP_OPEN}#{inner.text}#{FieldTemplateParser::GROUP_CLOSE}", [] if
        inner.parts.none?

      conditions, values = inner.parts.partition(&:condition)
      return dropped unless conditions.all?(&:present)
      return inner if values.none?

      values.any?(&:present) ? inner : dropped
    end

    def dropped
      Rendered.new '', []
    end

    # Decided on the stored value, not on the formatted one: a boolean field
    # holds "0" for false, which is a value but not something to show. Numbers
    # are left alone, a "0" of pieces is a statement of its own. A multi value
    # field answers with [nil] while it is empty, which is not blank on its own
    # and would keep its group in the line.
    def value_present?(record, name)
      placeholder = field_name name
      field = field_for placeholder unless reserved? placeholder
      value = compared_value record, field, placeholder
      value = value.compact_blank if value.is_a? Array
      operator, expected = condition name
      return value.present? && !(field&.field_format == 'bool' && value == '0') if operator.nil?

      met = expected.any? { |single| condition_met? value, single, operator }
      operator.start_with?('!') ? !met : met
    end

    # One of the values a condition asks for. "none" and "any" are about the
    # presence of a value, every other one about what it is - which a missing
    # value never is.
    def condition_met?(value, expected, operator)
      return value.blank? if expected.casecmp? BLANK_CONDITION
      return value.present? if expected.casecmp? PRESENT_CONDITION
      return false if value.blank?

      operator.end_with?('~') ? contains?(value, expected) : matches?(value, expected)
    end

    # Compared is the stored value, not the printed one: a list value and a tag
    # are the same either way, and those are what a condition is written for.
    # Where an attribute is stored as something nobody knows, its source names
    # a key instead which does not change with the language.
    def compared_value(record, field, placeholder)
      return (record.custom_field_value field.id if @source.field_readable? field) if field
      return '' unless readable? placeholder

      return @source.condition_value record, placeholder.downcase if reserved? placeholder

      attribute_value record, placeholder
    end

    # A field holding more than one value - and the tags - are asked whether
    # they contain the value, a single one whether it is the value. Written by
    # hand like the field names, so it is read the same way.
    def matches?(value, expected)
      Array(value).any? { |single| single.to_s.casecmp? expected }
    end

    def contains?(value, expected)
      Array(value).any? { |single| single.to_s.downcase.include? expected.downcase }
    end

    # A leading "?" marks a placeholder which only decides about its group and
    # prints nothing, for a group whose content is fixed text. An operator
    # splits off the values the condition asks for.
    def field_name(name)
      placeholder_parts(name).first.to_s
    end

    # The operator of a condition and the values it asks for, any of which is
    # enough; nil where it only asks whether the field is filled at all. An
    # empty value is a typo: it could never be true, and reads like "the field
    # is empty", which it does not mean.
    def condition(name)
      _field, operator, value = placeholder_parts name
      return if operator.nil?

      values = value.split(VALUE_SEPARATOR, -1).map(&:strip)
      raise Error.new(:error_field_template_condition_without_value, name: name) if values.empty? || values.any?(&:empty?)

      [operator, values]
    end

    # Only a condition carries an operator, so only there is the name split.
    # A field whose name contains one stays addressable everywhere else.
    def placeholder_parts(name)
      return [name] unless name.start_with? CONDITION_PREFIX

      # "{%? Sun = Afternoon %}" names the field Sun, like "{%?Sun=Afternoon%}"
      body = name.delete_prefix CONDITION_PREFIX
      match = CONDITION_RE.match body
      return [body.strip] if match.nil?

      field, operator, value = match.captures
      [field.strip, operator, value]
    end

    # Everything is matched case insensitively; an unknown placeholder has to
    # be reported instead of silently printing nothing.
    def value_for(record, name)
      placeholder = field_name name
      return '' unless readable? placeholder

      attribute_value record, placeholder
    end

    # What a placeholder prints here at all: it must be allowed in this
    # template, and the source must not have it turned off.
    def readable?(placeholder)
      check_scope placeholder

      @source.placeholder_enabled? placeholder.downcase
    end

    def attribute_value(record, placeholder)
      return @source.attribute_value record, placeholder.downcase if reserved? placeholder

      custom_field_value record, find_field(placeholder)
    end

    # Refused rather than cut down to something harmless: whoever writes it
    # into the template means the text, and a shortened one would look like
    # the template worked.
    def check_scope(placeholder)
      key = placeholder.downcase
      return if @source.placeholders.key?(key) || !reserved?(key)

      raise Error.new(:error_field_template_placeholder_not_allowed, name: placeholder)
    end

    # The stored value is not what a reader expects: a record reference holds
    # an id, a date the database format, a boolean "0" or "1". Every format
    # casts its value back to a ruby object, which is formatted from here on.
    def custom_field_value(record, field)
      return '' unless @source.field_readable? field

      value = record.custom_field_value field.id
      return '' if value.blank?

      values = casted_values field, value, record
      values.compact!
      values.map! { |casted| readable casted }
      values.to_comma_list
    end

    def casted_values(field, value, record)
      references = @references&.[] field.id
      if references
        # a record outside of the preloaded ones is cast like it would be
        return Array(value).filter_map { |id| references.fetch(id.to_i) { field.format.cast_value field, id, record } }
      end

      Array field.format.cast_value(field, value, record)
    end

    # The fields a template names, by placeholder and as arguments of a
    # function, which load references the way core does: one record per
    # value. A format which casts on its own is left to do so.
    def referenced_fields(template)
      fields = referenced_names(tree(template)).filter_map { |name| field_for name unless reserved? name }
      fields.uniq!
      fields.select { |field| reference_class field }
    end

    def referenced_names(nodes)
      nodes.flat_map do |node|
        case node
        when FieldTemplateParser::Placeholder then [field_name(node.name)]
        when FieldTemplateParser::Function then node.arguments.filter_map { |argument| argument.value unless argument.literal }
        when FieldTemplateParser::Group then referenced_names node.children
        else []
        end
      end
    end

    # The class whose records a field references, nil where its format casts
    # on its own. A user field casts to a principal from Redmine 7.1 on, which
    # admits groups; under 7.0 it holds users only, which Principal finds as
    # well.
    def reference_class(field)
      format = field.format
      return Principal if format.is_a? Redmine::FieldFormat::UserFormat
      return unless format.is_a? Redmine::FieldFormat::RecordList

      format.target_class if format.class.instance_method(:cast_single_value).owner == Redmine::FieldFormat::RecordList
    end

    # The source answers first, for a record it knows by another label than
    # its name. A wiki page has a title instead of a name, everything else
    # which can be referenced answers to name.
    def readable(value)
      label = @source.readable value
      return label unless label.nil?

      case value
      when Date, Time then format_date value
      when true then l :general_text_Yes
      when false then l :general_text_No
      when ->(object) { object.respond_to? :name } then value.name
      when ->(object) { object.respond_to? :pretty_title } then value.pretty_title
      else value.to_s
      end
    end

    def printed_value(record, name)
      if name.start_with? CONDITION_PREFIX
        # it prints nothing, but a placeholder which is not allowed here stays
        # not allowed - otherwise the rule would depend on the brackets around
        # it
        check_scope field_name(name)
        return ''
      end

      value = value_for record, name
      value = value.to_comma_list if value.is_a? Array
      # escaping it the redmine way keeps the value readable
      @escape_macros ? value.gsub('{{', '!{{') : value
    end
  end
end
