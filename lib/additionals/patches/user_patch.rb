# frozen_string_literal: true

module Additionals
  module Patches
    module UserPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
      end

      class_methods do
        def admin_column_field
          Redmine::Plugin.installed?('redmine_sudo') ? 'sudoer' : 'admin'
        end

        # NOTE: this is a better (performance related) solution as:
        # authors = users.to_a.select { |u| u.allowed_to? permission, project, global: project.nil? }
        def with_permission(permission, project = nil)
          # Clear cache for debuging performance issue
          # ActiveRecord::Base.connection.clear_query_cache

          role_ids = Role.builtin(false).select { |p| p.permissions.include? permission }
          role_ids.map!(&:id)

          admin_ids = User.visible.active.where(admin: true).ids

          member_scope = Member.joins(:member_roles, :project)
                               .where(projects: { status: Project::STATUS_ACTIVE },
                                      user_id: User.all,
                                      member_roles: { role_id: role_ids })
                               .select(:user_id)
                               .distinct

          if project.nil?
            # user_ids = member_scope.pluck(:user_id) | admin_ids
            # where(id: user_ids)
            where(id: member_scope).or(where(id: admin_ids))
          else
            # user_ids = member_scope.where(project_id: project).pluck(:user_id)
            # where(id: user_ids).or(where(id: admin_ids))
            where(id: member_scope.where(project_id: project)).or(where(id: admin_ids))
          end
        end
      end

      module InstanceMethods
        def can_be_admin?
          @can_be_admin ||= Redmine::Plugin.installed?('redmine_sudo') ? (admin || sudoer) : admin
        end

        def issues_assignable?(project = nil)
          scope = Principal.joins(members: :roles)
                           .where(users: { id: id },
                                  roles: { assignable: true })
          scope = scope.where members: { project_id: project.id } if project
          scope.exists?
        end
      end
    end
  end
end
