# frozen_string_literal: true

module Additionals
  module Patches
    module PrincipalPatch
      extend ActiveSupport::Concern

      included do
        scope :assignable, -> { active.visible.where type: %w[User Group] }

        scope :assignable_for_issues, lambda { |*args|
          project = args.first
          users = assignable
          users = users.where.not type: 'Group' unless Setting.issue_group_assignment?
          users = users.joins(members: :roles)
                       .where(roles: { assignable: true })
                       .distinct
          users = users.member_of project if project.present?
          users
        }

        # TODO: find better solution, which not requires overwrite visible
        # to filter out hide role members
        scope :visible, lambda { |*args|
          user = args.first || User.current

          if user.admin?
            all
          else
            view_all_active = if user.memberships.to_a.any?
                                user.memberships.any? { |m| m.roles.any? { |r| r.users_visibility == 'all' } }
                              else
                                user.builtin_role.users_visibility == 'all'
                              end

            if view_all_active
              active
            else
              # self and members of visible projects
              scope = if user.allowed_to? :show_hidden_roles_in_memberbox, nil, global: true
                        active.where("#{table_name}.id = ? OR #{table_name}.id IN (SELECT user_id " \
                                     "FROM #{Member.table_name} WHERE project_id IN (?))",
                                     user.id, user.visible_project_ids)
                      else
                        active.where("#{table_name}.id = ? OR #{table_name}.id IN (SELECT user_id " \
                                     "FROM #{Member.table_name} JOIN #{MemberRole.table_name} " \
                                     " ON #{Member.table_name}.id = #{MemberRole.table_name}.member_id"  \
                                     " JOIN #{Role.table_name} " \
                                     " ON #{Role.table_name}.id = #{MemberRole.table_name}.role_id"  \
                                     " WHERE project_id IN (?) AND #{Role.table_name}.hide = ?)",
                                     user.id, user.visible_project_ids, false)
                      end

              scope
            end
          end
        }
      end
    end
  end
end
