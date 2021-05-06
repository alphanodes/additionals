# frozen_string_literal: true

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
        # Used by Redmine >= 4.2
        def principals_by_role
          # includes = Redmine::Plugin.installed?('redmine_hrm') ? [:roles, { principal: :hrm_user_type }] : %i[roles principal]
          includes = %i[principal roles]
          memberships.includes(includes).each_with_object({}) do |m, h|
            m.roles.each do |r|
              next if r.hide && !User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)

              h[r] ||= []
              h[r] << m.principal
            end
            h
          end
        end

        # Used by Redmine < 4.2
        # this change take care of hidden roles and performance issues (includes for hrm, if installed)
        def users_by_role
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

      module InstanceMethods
        # without hidden roles!
        def all_principals_by_role
          memberships.includes(:principal, :roles).each_with_object({}) do |m, h|
            m.roles.each do |r|
              h[r] ||= []
              h[r] << m.principal
            end
            h
          end
        end

        def visible_principals
          query = ::Query.new project: self, name: '_'
          query&.principals
        end

        def visible_users
          query = ::Query.new project: self, name: '_'
          query&.users
        end

        # assignable_users result depends on Setting.issue_group_assignment?
        # this result is not depending on issue settings
        def assignable_users_and_groups
          Principal.assignable
                   .joins(members: :roles)
                   .where(members: { project_id: id },
                          roles: { assignable: true })
                   .distinct
                   .sorted
        end
      end
    end
  end
end
