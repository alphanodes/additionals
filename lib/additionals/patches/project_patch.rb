module Additionals
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods

        has_many :dashboards, dependent: :destroy
      end

      module InstanceOverwriteMethods
        # this change take care of hidden roles and performance issues (includes for hrm, if installed)
        def users_by_role
          if Redmine::VERSION.to_s >= '4.2'
            includes = Redmine::Plugin.installed?('redmine_hrm') ? [:roles, { principal: :hrm_user_type }] : %i[roles principal]
            memberships.includes(includes).each_with_object({}) do |m, h|
              m.roles.each do |r|
                next if r.hide && !User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)

                h[r] ||= []
                h[r] << m.principal
              end
              h
            end
          else
            includes = Redmine::Plugin.installed?('redmine_hrm') ? [:roles, { user: :hrm_user_type }] : %i[roles user]
            members.includes(includes).each_with_object({}) do |m, h|
              m.roles.each do |r|
                next if r.hide && !User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)

                h[r] ||= []
                h[r] << m.user
              end
              h
            end
          end
        end

        def users_by_role_old
          roles_with_users = if Redmine::VERSION.to_s >= '4.2'
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
