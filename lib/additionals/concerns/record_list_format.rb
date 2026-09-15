# frozen_string_literal: true

module Additionals
  module Concerns
    # Renders the value of a RecordList custom field format whose records belong
    # to a plugin model. Core hands the value to the format class and, without
    # this, falls back to format_object, which has no branch for such a model and
    # prints to_s. Rendering here keeps ApplicationHelper#format_object untouched
    # and leaves core's visibility check in front of it.
    #
    # The including format names the view helper that renders a single record.
    # Redmine runs with include_all_helpers = false, so the helper is not
    # available in every view - plain text is the fallback there.
    module RecordListFormat
      def formatted_custom_value(view, custom_value, html = false) # rubocop:disable Style/OptionalBooleanParameter
        records = target_class.where id: custom_value.value
        return records.map(&:to_s).to_comma_list unless html && view.respond_to?(record_renderer)

        view.safe_join records.map { |record| view.public_send record_renderer, record }, ', '
      end
    end
  end
end
