# frozen_string_literal: true

module Additionals
  module Patches
    module AccessControlPatch
      extend ActiveSupport::Concern

      class_methods do
        def available_project_modules_all
          @permissions.collect(&:project_module).compact!.uniq
        end
      end
    end

    module AccessControlClassPatch
      def available_project_modules
        super.reject { |m| Additionals.setting(:disabled_modules).to_a.include?(m.to_s) }
      end
    end
  end
end
