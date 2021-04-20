# frozen_string_literal: true

require_dependency 'query'

module Additionals
  module Patches
    module QueryFilterPatch
      unless method_defined? :[]=
        # NOTE: used for select2 fields
        def []=(key, value)
          return unless key == :values

          @value = @options[:values] = value
        end
      end
    end
  end
end
