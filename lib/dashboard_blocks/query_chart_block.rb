# frozen_string_literal: true

module DashboardBlocks
  # A chart of a saved query (AdditionalsQueryChart). The block holds its
  # chart: chart classes are used outside of dashboards as well and know
  # nothing about them.
  class QueryChartBlock < Base
    abstract!

    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS

    class_attribute :chart_class, instance_writer: false

    class << self
      def chart(klass = nil)
        klass ? self.chart_class = klass : chart_class
      end

      def async(**options)
        return super if options.any?

        async_options || { required_settings: %i[group_by],
                           partial: 'dashboards/blocks/query_chart',
                           libraries: %i[chartjs_meta],
                           lazy: true,
                           data_check_class: chart }
      end
    end

    def to_definition
      super.merge query_chart: { class: self.class.chart }
    end
  end
end
