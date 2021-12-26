# frozen_string_literal: true

module Additionals
  module Patches
    module QueryPatch
      extend ActiveSupport::Concern

      included do
        attr_accessor :search_string
      end

      class_methods do
        def additional_csv_separator
          l(:general_csv_separator) == ',' ? ';' : ','
        end
      end
    end
  end
end
