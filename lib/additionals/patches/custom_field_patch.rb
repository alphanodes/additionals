# frozen_string_literal: true

module Additionals
  module Patches
    module CustomFieldPatch
      extend ActiveSupport::Concern

      included do
        # Text and icon shown before and after the values of a number list.
        # Declared here and not with field_attributes in the format: the format
        # is loaded once, CustomField again after every code reload in development.
        store_accessor :format_store, :value_prefix, :value_prefix_icon, :value_suffix, :value_suffix_icon
        safe_attributes 'value_prefix', 'value_prefix_icon', 'value_suffix', 'value_suffix_icon'
      end
    end
  end
end
