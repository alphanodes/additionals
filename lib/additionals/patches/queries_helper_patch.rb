# frozen_string_literal: true

module Additionals
  module Patches
    module QueriesHelperPatch
      extend ActiveSupport::Concern
      included do
        def additional_csv_separator
          l(:general_csv_separator) == ',' ? ';' : ','
        end
      end
    end
  end
end
