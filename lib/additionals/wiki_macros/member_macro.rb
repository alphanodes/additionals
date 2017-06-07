# Member wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-EOHELP
  Display members.

  Syntax:

    {{members([PROJECT_NAME, title=My members list, role=ROLE)]}}

    PROJECT_NAME can be project identifier, project name or project id

    Examples:

    {{members}}
    ...List all members for all projects (with the current user permission)

    {{members(the-identifier)}}
    ...A box showing all members for the project with the identifier of 'the-identifier'

    {{members(the-identifier, role=Manager)}}
    ...A box showing all members for the project with the identifier of 'the-identifier', which
    have the role "Manager"

    {{members(the-identifier, title=My user list)}}
    ...A box showing all members for the project with the identifier of 'the-identifier' and with
    box title "My user list"

  EOHELP

      macro :members do |_obj, args|
        args, options = extract_macro_options(args, :role, :title)

        project_id = args[0]
        user_roles = []

        if project_id.present?
          project_id.strip!

          project = Project.visible.find_by(id: project_id)
          project ||= Project.visible.find_by(identifier: project_id)
          project ||= Project.visible.find_by(name: project_id)
          return '' if project.nil?

          raw_users = User.active
                          .where(["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id=(?))", project.id])
                          .sort
          return '' if raw_users.nil?

          users = []
          raw_users.each do |user|
            user_roles[user.id] = user.roles_for_project(project)
            if options[:role].blank? || Additionals.check_role_matches(user_roles[user.id], options[:role])
              users << user
            end
          end
        else
          project_ids = Project.visible.collect(&:id)
          return '' unless project_ids.any?
          # members of the user's projects
          users = User.active
                      .where(["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", project_ids])
                      .sort
        end
        render partial: 'wiki/user_macros', locals: { users: users,
                                                      user_roles: user_roles,
                                                      list_title: options[:title] }
      end
    end
  end

  def self.check_role_matches(roles, filters)
    filters.tr('|', ',').split(',').each do |filter|
      roles.each { |role| return true if filter.to_s == role.to_s }
    end
    false
  end
end
