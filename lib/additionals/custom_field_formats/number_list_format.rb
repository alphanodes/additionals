# frozen_string_literal: true

module Redmine
  module FieldFormat
    # A list of fixed numbers, e.g. a scale of 1, 2, 3, 5, 8. Edited like a list
    # (select or radio buttons), evaluated like a number: the stored value is
    # the number itself, so totals, sorting and grouping work as with the
    # integer and float formats.
    class NumberListFormat < ListFormat
      add 'number_list'

      # A total over several values of one object would not mean anything
      self.multiple_supported = false
      # A text search for "8" only finds noise
      self.searchable_supported = false
      self.totalable_supported = true
      self.form_partial = 'custom_fields/formats/additionals_number_list'

      # Up to three decimals, like the numeric cast of core (decimal(30,3))
      PRECISION = 3

      class << self
        # The stored value as a number: an Integer for whole numbers, so 13
        # stays 13 instead of 13.0, a Float otherwise
        def number(value)
          decimal = BigDecimal value.to_s.strip, exception: false
          return if decimal.nil? || !decimal.finite?

          decimal.frac.zero? ? decimal.to_i : decimal.to_f
        end

        # Class of a displayed value, so a theme can style single values:
        # number-list-value-13, number-list-value-0-5
        def css_class(value)
          "number-list-value-#{value.to_s.strip.tr '.', '-'}"
        end

        # The number in the notation of the current language (0,5 in German)
        def localized(value)
          number = number value
          return value.to_s if number.nil?

          ActiveSupport::NumberHelper.number_to_rounded number, precision: PRECISION,
                                                                strip_insignificant_zeros: true
        end
      end

      def label
        'label_number_list'
      end

      def validate_custom_field(custom_field)
        errors = super
        values = Array.wrap custom_field.possible_values
        numbers = values.map { |value| self.class.number value }
        if numbers.include? nil
          errors << %i[possible_values invalid]
        elsif numbers.uniq.size < numbers.size
          errors << %i[possible_values taken]
        end
        errors
      end

      def cast_single_value(_custom_field, value, _customized = nil)
        self.class.number value
      end

      def cast_total_value(_custom_field, value)
        number = self.class.number value
        number.is_a?(Float) ? number.round(2) : number
      end

      # The number in the language of the user. A string, so format_object does
      # not turn 0.5 into "0.50" like it does with floats. Prefix and suffix
      # ("$ 500", "21 SP") belong to pages and lists only: selections show the
      # number next to the field name, exports and APIs need the plain number.
      def formatted_value(view, custom_field, value, _customized = nil, html = false) # rubocop:disable Style/OptionalBooleanParameter
        text = self.class.localized value
        return text unless html && text.present?

        parts = [affix_icon(view, custom_field.value_prefix_icon, 'number-list-prefix-icon'), custom_field.value_prefix,
                 text,
                 custom_field.value_suffix, affix_icon(view, custom_field.value_suffix_icon, 'number-list-suffix-icon')]
        view.tag.span view.safe_join(parts.compact_blank, ' '), class: ['number-list-value', self.class.css_class(value)]
      end

      def possible_values_options(custom_field, _object = nil)
        Array.wrap(custom_field.possible_values).map { |value| [self.class.localized(value), value] }
      end

      # A value no longer in the list stays selectable on the object holding it,
      # like with core lists
      def possible_custom_value_options(custom_value)
        options = possible_values_options custom_value.custom_field
        missing = Array.wrap(custom_value.value).compact_blank - options.map(&:last)
        options + missing.map { |value| [self.class.localized(value), value] }
      end

      # Sorting, grouping and totals of the integer format: the database casts
      # the values to numbers, so 2 comes before 13
      def order_statement(custom_field)
        IntFormat.instance.order_statement custom_field
      end

      def total_for_scope(custom_field, scope)
        IntFormat.instance.total_for_scope custom_field, scope
      end

      private

      def affix_icon(view, icon, css_class)
        return if icon.blank?

        view.additionals_icon icon, css_class: css_class
      end
    end
  end
end
