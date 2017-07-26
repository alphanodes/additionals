module Additionals
  module Patches
    module AccessControlPatch
      def self.included(base)
        base.class_eval do
          def self.available_project_modules
            @available_project_modules = available_project_modules_all
                                         .reject { |m| Additionals.settings[:disabled_modules].to_a.include?(m.to_s) }
          end

          def self.available_project_modules_all
            @permissions.collect(&:project_module).uniq.compact
          end
        end
      end
    end
  end
end

unless Redmine::AccessControl.included_modules.include? Additionals::Patches::AccessControlPatch
  Redmine::AccessControl.send(:include, Additionals::Patches::AccessControlPatch)
end
