# frozen_string_literal: true

module Additionals
  module Patches
    module PrincipalPatch
      extend ActiveSupport::Concern

      SELECT2_FIELDS = %i[principal
                          user
                          assignee
                          issue_assignee
                          author
                          author_optional
                          user_with_me
                          global_user
                          internal_user].freeze

      included do
        scope :assignable, -> { active.visible.where type: %w[User Group] }

        # Subquery wrap: the inner SELECT-DISTINCT lives without ORDER BY
        # (caller chains `.sorted` after the scope, which adds ORDER BY on
        # `users.type`/`firstname`/`lastname`). PostgreSQL rejects
        # SELECT DISTINCT … ORDER BY x when x is not in the SELECT list,
        # which trips on the JOINs through members/roles. Wrapping the
        # DISTINCT-id selection in a subquery and applying ORDER BY on the
        # outer plain SELECT keeps both adapters happy.
        scope :assignable_for_issues, lambda { |*args|
          project = args.first
          ids_scope = assignable.joins(members: :roles)
                                .where(roles: { assignable: true })
          ids_scope = ids_scope.where.not(type: 'Group') unless Setting.issue_group_assignment?
          ids_scope = ids_scope.where(members: { project_id: project.id }) if project.present?

          where id: ids_scope.select(:id)
        }

        # TODO: find better solution, which not requires overwrite visible
        # to filter out hide role members
        scope :visible, lambda { |*args|
          user = args.first || User.current

          if user.admin? || AdditionalsPlugin.active_hrm? && user.hrm_allowed_to?(:view_hrm)
            all
          else
            view_all_active = if user.memberships.any?
                                User.where(id: user.id)
                                    .joins(memberships: :roles)
                                    .exists?(roles: { users_visibility: 'all' })
                              else
                                user.builtin_role.users_visibility == 'all'
                              end

            if view_all_active
              active
            else
              # Self and members of visible projects. A correlated EXISTS instead of
              # "id IN (SELECT user_id ...)": with many memberships the IN subquery
              # materializes nearly all members rows. Own aliases, because
              # assignable_for_issues already joins members, member_roles and roles.
              if user.allowed_to? :show_hidden_roles_in_memberbox, nil, global: true
                active.where("#{table_name}.id = ? OR EXISTS (SELECT 1 FROM #{Member.table_name} vm" \
                             " WHERE vm.user_id = #{table_name}.id AND vm.project_id IN (?))",
                             user.id, user.visible_project_ids)
              else
                active.where("#{table_name}.id = ? OR EXISTS (SELECT 1 FROM #{Member.table_name} vm" \
                             " JOIN #{MemberRole.table_name} vmr ON vmr.member_id = vm.id" \
                             " JOIN #{Role.table_name} vr ON vr.id = vmr.role_id" \
                             " WHERE vm.user_id = #{table_name}.id AND vm.project_id IN (?) AND vr.hide = ?)",
                             user.id, user.visible_project_ids, false)
              end
            end
          end
        }
      end

      class_methods do
        def ids_to_names_with_ids(ids)
          names_with_ids = []
          return names_with_ids if ids.blank?

          ids_without_me = ids.dup
          with_me = ids_without_me.delete 'me'

          names_with_ids << Query.label_me_value if ids_without_me.blank? || with_me
          return names_with_ids if ids.blank?

          names_with_ids + visible.where(id: ids_without_me).map { |c| [c.name, c.id.to_s] }
        end
      end
    end
  end
end
