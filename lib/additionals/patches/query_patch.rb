module Additionals
  module Patches
    module QueryPatch
      def self.included(base)
        base.send(:prepend, InstancOverwriteMethods)
      end

      module InstancOverwriteMethods
        def users
          super
        end
      end
    end
  end
end
