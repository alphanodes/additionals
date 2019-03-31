module Additionals
  module Patches
    module UserPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
      end

      module InstanceMethods
        def issues_assignable?(project = nil)
          scope = Principal.joins(members: :roles)
                           .where(users: { id: id }, roles: { assignable: true })
          scope = scope.where(members: { project_id: project.id }) if project
          scope.exists?
        end
      end
    end
  end
end
