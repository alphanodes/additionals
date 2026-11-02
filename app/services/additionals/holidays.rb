# frozen_string_literal: true

module Additionals
  # Days off on top of the non-working week days, the one answer for all
  # plugins. Redmine 7.1 registers them as non-working dates
  # (https://www.redmine.org/issues/1459). A plugin that manages holidays
  # itself prepends its own answer, which then applies everywhere.
  class Holidays
    class << self
      # Sorted dates off for everybody, within range or all without one
      def dates(range = nil)
        non_working_dates range
      end

      # Sorted dates off for user, a plugin may add regional ones
      def dates_for(_user, range = nil)
        dates range
      end

      def holiday?(date)
        dates(date..date).any?
      end

      # TODO(Redmine 7.0 EOL): drop the check
      def non_working_dates(range = nil)
        return [] unless defined?(::NonWorkingDate)

        dates = NonWorkingDate.sorted_dates
        range ? dates.select { |date| range.cover? date } : dates.dup
      end
    end
  end
end
