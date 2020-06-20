require_dependency 'query'

module Additionals
  module Patches
    module QueryFilterPatch
      unless method_defined? :[]=
        def []=(key, value)
          return unless key == :values

          @value = @options[:values] = value
        end
      end
    end
  end
end
