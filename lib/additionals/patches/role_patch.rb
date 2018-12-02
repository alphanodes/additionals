module Additionals
  module Patches
    module RolePatch
      def self.included(base)
        base.class_eval do
          safe_attributes 'hide'
        end
      end
    end
  end
end
