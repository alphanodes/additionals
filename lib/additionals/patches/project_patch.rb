# frozen_string_literal: true

module Additionals
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        include InstanceMethods

        has_many :dashboards, dependent: :destroy

        safe_attributes 'enable_new_ticket_message', 'new_ticket_message'
      end

      module InstanceOverwriteMethods
        def principals_by_role
          # includes = AdditionalsPlugin.active_hrm? ? [:roles, { principal: :hrm_user_type }] : %i[roles principal]
          includes = %i[principal member_roles roles]
          memberships.active.includes(includes).each_with_object({}) do |m, h|
            m.roles.each do |r|
              next if r.hide && !User.current.allowed_to?(:show_hidden_roles_in_memberbox, project)

              h[r] ||= []
              h[r] << m.principal
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
        # NOTE: user and groups
        def assignable_principals
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
