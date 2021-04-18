# frozen_string_literal: true

module Additionals
  module Patches
    module AccessControlPatch
      extend ActiveSupport::Concern

      included do
        def self.available_project_modules
          @available_project_modules = available_project_modules_all
                                       .reject { |m| Additionals.setting(:disabled_modules).to_a.include?(m.to_s) }
        end

        def self.available_project_modules_all
          @permissions.collect(&:project_module).compact!.uniq
        end
      end
    end
  end
end
