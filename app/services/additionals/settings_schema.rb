# frozen_string_literal: true

module Additionals
  # Settings declared as data, e.g. the settings of a dashboard block: a hash of
  # keys with their type and rules, read with values in a context.
  #
  #   schema = Additionals::SettingsSchema.new(
  #     { url: { type: :string, label: :field_url, required: true },
  #       max_entries: { type: :integer, min: 1, max: 100, default: 10 } },
  #     params[:settings], project: @project
  #   )
  #   schema.valid?    # errors per key, also for a program
  #   schema.settings  # the values to store, as the forms send them
  #   schema[:max_entries] # => 10, typed and with its default
  #   schema.describe  # plain hashes for programmatic clients
  #
  # Options of a setting:
  # - type: string, text, integer, float, boolean, enum or list
  # - label, info: locale key, text or lambda. An info marked as HTML safe
  #   (e.g. with a link) is described as text, unless for a form
  # - placeholder: shown in an empty field of a form, e.g. what the block shows
  #   without the setting; locale key, text or lambda
  # - values: allowed values, plain or [label, value], for enum and list. A
  #   given unique label is stored as its value
  # - offered: the allowed values a form offers for the other values, e.g.
  #   only some display types for a timeline. Other allowed values stay valid,
  #   whoever reads them falls back.
  # - default, required, min, max. A required setting with a default is only
  #   missing if given blank
  # - secret: a token, key or password; its value is never described, and a
  #   form built from the settings never fills it in
  # - field: partial of its field in a form built from the settings, for a
  #   setting the fields of the types cannot show (e.g. checkboxes of a list);
  #   wide: the field has the width of the form, with labels of its own
  # - if: whether the setting exists in the context at all; if not, it counts
  #   as an unknown key
  # - applies: whether the setting applies to the other values. One that does
  #   not apply is kept and not required, so switching back restores it.
  # - shown_with: key of a boolean setting; a form shows the field only while
  #   it is on, e.g. own columns of a query list
  # - reset_by: key of another setting; a given change of it drops the stored
  #   value and ignores a given one, e.g. columns of a list with another query
  #
  # Values, labels and rules can be lambdas, they get the schema to read the
  # other values (schema[:key]) and the context (schema.context).
  #
  # Stored values (stored:) complete the given ones. They were accepted when
  # they were saved and are only checked for required settings: a query the
  # current user cannot see, or a column removed since, must not lock the
  # settings of a block for an editor who did not choose them.
  #
  # Values are stored as the forms send them: booleans as "1"/"0", numbers as
  # strings, blank meaning none. Readers of the stored settings stay unchanged.
  class SettingsSchema
    include Redmine::I18n

    TYPES = %i[string text integer float boolean enum list].freeze
    LABELED_TYPES = %i[enum list].freeze
    OPTIONS = %i[type label info placeholder values offered default required min max if applies shown_with reset_by
                 field wide secret].freeze
    # Options of a setting an object can answer with a method named after the
    # setting, see with_rule_methods
    RULE_METHODS = { if: '%s_available?', applies: '%s_applies?', values: '%s_values', offered: '%s_offered',
                     default: '%s_default', label: '%s_label', info: '%s_info',
                     placeholder: '%s_placeholder' }.freeze
    TRUE_VALUES = ['1', 'true', true, 1].freeze
    FALSE_VALUES = ['0', 'false', false, 0, ''].freeze
    INTEGER_FORMAT = /\A[+-]?\d+\z/
    FLOAT_FORMAT = /\A[+-]?\d+(\.\d+)?\z/
    NUMBER_TYPES = %i[integer float].freeze

    attr_reader :context

    # Definitions completed by the rules an object answers with methods named
    # after the setting and called with the schema, e.g. for a dashboard block
    # with_subprojects_available?(schema) as if of with_subprojects. prefix
    # names the methods of objects that have methods of other kinds too (a
    # query: query_option_<key>_values), except leaves out methods that are
    # no rules although named like one.
    def self.with_rule_methods(definitions, object, prefix: '', except: [])
      definitions.to_h do |key, definition|
        rules = RULE_METHODS.each_with_object({}) do |(option, method_name), found|
          name = :"#{prefix}#{format method_name, key}"
          found[option] = object.method name if object.respond_to?(name, true) && except.exclude?(name)
        end
        [key, definition.merge(rules)]
      end
    end

    def initialize(definitions, values = {}, stored: {}, **context)
      @definitions = definitions.to_h { |key, definition| [key.to_sym, check_definition(key, definition)] }
      @context = context
      @invalid = {}
      values = values.to_h.symbolize_keys
      @stored = stored.to_h.symbolize_keys
      @reset_keys = @definitions.keys.select { |key| reset_by_change? key, values }
      @stored = @stored.except(*@reset_keys)
      @not_applied_resets = values.keys & @reset_keys
      values = values.except(*@reset_keys)
      @given_keys = values.keys
      @values = cast_values(@stored.except(*@given_keys), check: false).merge cast_values(values)
      resolve_labels
    end

    # The stored value of a setting as stored, e.g. for a rule that keeps it
    # valid although it would no longer be offered
    def stored(key)
      @stored[key.to_sym]
    end

    # Typed value of a setting, its default if it is blank or a number out of
    # its bounds (e.g. stored before they were declared)
    def [](key)
      key = key.to_sym
      definition = @definitions[key]
      return if definition.nil?

      value = @values[key]
      return default_for definition if value.blank? || !readable_number?(definition, value)

      typed_value definition[:type], value
    end

    # The given and stored values as stored, before any default, e.g. to build
    # an object that knows the rules
    def values
      @values.dup
    end

    # Values to store: declared, available settings only
    def settings
      @values.slice(*available_keys)
    end

    # Settings that exist in the context
    def available_keys
      @available_keys ||= @definitions.keys.select do |key|
        condition = @definitions[key][:if]
        condition.nil? || resolve(condition)
      end
    end

    # Given settings that exist but do not apply to the other values or were
    # reset by a change of another one (reset_by)
    def not_applied_keys
      (@given_keys & available_keys).reject { |key| applies? key } + (@not_applied_resets & available_keys)
    end

    # Unknown keys and settings that do not exist in the context
    def ignored_keys
      @ignored_keys ||= (@given_keys - available_keys).sort
    end

    def valid?
      errors.empty?
    end

    def errors
      @errors ||= available_keys.each_with_object({}) do |key, errors|
        messages = errors_for key
        errors[key] = messages if messages.any?
      end
    end

    def full_messages
      errors.flat_map { |key, messages| messages.map { |message| "#{label_for key} #{message}" } }
    end

    # html: an info marked as HTML safe as it is, e.g. for a form
    def describe(html: false)
      available_keys.map { |key| description_for key, html: }
    end

    def label_for(key)
      label = resolve @definitions[key][:label]
      label.is_a?(Symbol) ? l(label) : (label.presence || key.to_s.humanize)
    end

    private

    def check_definition(key, definition)
      unknown = definition.keys - OPTIONS
      raise ArgumentError, "unknown options #{unknown.inspect} for setting #{key}" if unknown.any?
      raise ArgumentError, "unknown type #{definition[:type].inspect} for setting #{key}" if TYPES.exclude? definition[:type]

      definition
    end

    def cast_values(values, check: true)
      values.each_with_object({}) do |(key, value), cast|
        next unless @definitions.key?(key) && !value.nil?

        type = @definitions[key][:type]
        # A program may send anything, a single value must not be a structure
        if type != :list && (value.is_a?(Hash) || value.is_a?(Array))
          @invalid[key] = :invalid if check
          next
        end

        cast[key] = cast_value key, type, value
        @invalid.delete key unless check
      end
    end

    def cast_value(key, type, value)
      case type
      when :string, :enum
        value.to_s.strip
      when :text
        value.to_s
      when :integer, :float
        number = value.to_s.strip
        @invalid[key] = :not_a_number if number.present? && number !~ number_format(type)
        number
      when :boolean
        cast_boolean key, value
      when :list
        list = value.is_a?(String) ? value.split(',') : Array(value)
        list.map { |entry| entry.to_s.strip }.compact_blank
      end
    end

    # A program may give the label of an allowed value, e.g. the name of a query
    # instead of its id. Only a unique label counts, a value always wins. After
    # the casting: the allowed values may depend on the other values.
    def resolve_labels
      @given_keys.each do |key|
        definition = @definitions[key]
        next unless definition && LABELED_TYPES.include?(definition[:type]) && @values[key].present?

        values = values_for definition
        next if values.nil?

        @values[key] = if definition[:type] == :list
                         @values[key].map { |value| value_of_label values, value }
                       else
                         value_of_label values, @values[key]
                       end
      end
    end

    def value_of_label(values, value)
      return value if values.any? { |entry| entry[:value] == value }

      found = values.select { |entry| entry[:label].casecmp? value }
      found.one? ? found.first[:value] : value
    end

    def cast_boolean(key, value)
      if TRUE_VALUES.include? value
        '1'
      elsif FALSE_VALUES.include? value
        '0'
      else
        @invalid[key] = :inclusion
        value.to_s
      end
    end

    # A boolean without a default is off
    # A number given as text, e.g. from plugin settings, reads as number
    def default_for(definition)
      default = resolve definition[:default]
      return false if default.nil? && definition[:type] == :boolean
      return typed_value definition[:type], default if default.is_a?(String) && NUMBER_TYPES.include?(definition[:type])

      default
    end

    def readable_number?(definition, value)
      type = definition[:type]
      return true unless NUMBER_TYPES.include? type
      return false unless value.to_s.strip.match? number_format(type)

      number = typed_value type, value
      (definition[:min].nil? || number >= definition[:min]) && (definition[:max].nil? || number <= definition[:max])
    end

    def number_format(type)
      type == :integer ? INTEGER_FORMAT : FLOAT_FORMAT
    end

    def typed_value(type, value)
      case type
      when :integer
        value.to_i
      when :float
        value.to_f
      when :boolean
        value == '1'
      else
        value
      end
    end

    def applies?(key)
      condition = @definitions[key][:applies]
      condition.nil? || resolve(condition) ? true : false
    end

    # A setting whose reset_by setting is given with another value than stored
    def reset_by_change?(key, values)
      other = @definitions.dig key, :reset_by
      return false if other.nil? || !values.key?(other) || @stored[other].blank?

      values[other].to_s.strip != @stored[other].to_s
    end

    def errors_for(key)
      return [message(@invalid[key])] if @invalid.key? key

      definition = @definitions[key]
      value = @values[key]
      if value.blank?
        definition[:required] && applies?(key) && !defaulted?(key, definition) ? [message(:blank)] : []
      elsif @given_keys.include? key
        value_errors key, definition, value
      else
        []
      end
    end

    # A default fills a required setting nobody gave, only a given blank value
    # empties it
    def defaulted?(key, definition)
      @given_keys.exclude?(key) && !resolve(definition[:default]).nil?
    end

    # A stored choice sent back unchanged stays valid, even if the user cannot
    # choose it (e.g. a query of another user)
    def value_errors(key, definition, value)
      case definition[:type]
      when :integer, :float
        range_errors definition, typed_value(definition[:type], value)
      when :enum, :list
        allowed = allowed_values definition
        allowed.nil? || (Array(value) - allowed - Array(@stored[key]).map(&:to_s)).empty? ? [] : [message(:inclusion)]
      else
        []
      end
    end

    def range_errors(definition, number)
      errors = []
      errors << message(:greater_than_or_equal_to, count: definition[:min]) if definition[:min] && number < definition[:min]
      errors << message(:less_than_or_equal_to, count: definition[:max]) if definition[:max] && number > definition[:max]
      errors
    end

    def allowed_values(definition)
      values_for(definition)&.pluck(:value)
    end

    def values_for(definition)
      values = resolve definition[:values]
      return if values.nil?

      values.map do |value|
        label, value = value.is_a?(Array) ? value : [value, value]
        { value: value.to_s, label: label.to_s }
      end
    end

    def description_for(key, html:)
      definition = @definitions[key]
      { key:,
        type: definition[:type],
        label: label_for(key),
        description: info_for(definition, html:),
        placeholder: text_of(definition[:placeholder]),
        required: definition[:required] ? true : nil,
        default: resolve(definition[:default]),
        values: values_for(definition),
        offered: definition.key?(:offered) ? Array(resolve(definition[:offered])).map(&:to_s) : nil,
        min: definition[:min],
        max: definition[:max],
        applies: applies?(key),
        shown_with: definition[:shown_with],
        reset_by: definition[:reset_by],
        secret: definition[:secret] ? true : nil,
        value: @values.key?(key) && !definition[:secret] ? self[key] : nil }.compact
    end

    def info_for(definition, html:)
      info = text_of definition[:info]
      html || !info.html_safe? ? info : ActionView::Base.full_sanitizer.sanitize(info)
    end

    def text_of(option)
      text = resolve option
      text.is_a?(Symbol) ? l(text) : text
    end

    def resolve(option)
      option.respond_to?(:call) ? option.call(self) : option
    end

    def message(error, **)
      ::I18n.t "activerecord.errors.messages.#{error}", **
    end
  end
end
