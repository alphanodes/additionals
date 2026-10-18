# frozen_string_literal: true

module DashboardBlocks
  # Entries of a saved query as list, e.g. issues
  class QueryListBlock < Base
    abstract!

    max_occurs DashboardContent::MAX_MULTIPLE_OCCURS

    class_attribute :query_block_options, instance_writer: false

    class << self
      # The list of the query, see DashboardContent#block_definitions; a
      # label is a locale key
      def query_block(**options)
        options.any? ? self.query_block_options = options : query_block_options
      end
    end

    def to_definition
      options = self.class.query_block
      super.merge query_block: options.merge(label: I18n.t(options[:label]))
    end
  end
end
