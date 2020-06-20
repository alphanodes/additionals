module Additionals
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods
      end

      module InstanceOverwriteMethods
        def users_by_role
          roles_with_users = if Redmine::VERSION::BRANCH == 'devel'
                               principals_by_role
                             else
                               super
                             end

          roles_with_users.each do |role_with_users|
            role = role_with_users.first
            next unless role.hide

            roles_with_users.delete(role) unless User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)
          end

          roles_with_users
        end
      end

      module InstanceMethods
        def visible_principals
          query = ::Query.new(project: self, name: '_')
          query&.principals
        end

        def visible_users
          query = ::Query.new(project: self, name: '_')
          query&.users
        end

        # assignable_users result depends on Setting.issue_group_assignment?
        # this result is not depending on issue settings
        def assignable_users_and_groups
          Principal.active
                   .joins(members: :roles)
                   .where(type: %w[User Group],
                          members: { project_id: id },
                          roles: { assignable: true })
                   .distinct
                   .sorted
        end
      end
    end
  end
end
