# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display members.

  Syntax:

    {{members([PROJECT_NAME, title=My members list, role=ROLE, with_sum=BOOL)]}}

    PROJECT_NAME can be project identifier, project name or project id

  Examples:

    {{members}}
    ...List all members for all projects (with the current user permission)

    {{members(with_sum=true)}}
    ...List all members for all projects and show title with amount of members

    {{members(the-identifier)}}
    ...A box showing all members for the project with the identifier of 'the-identifier'

    {{members(the-identifier, role=Manager)}}
    ...A box showing all members for the project with the identifier of 'the-identifier', which
    have the role "Manager"

    {{members(the-identifier, title=My user list)}}
    ...A box showing all members for the project with the identifier of 'the-identifier' and with
    box title "My user list"
      DESCRIPTION

      macro :members do |_obj, args|
        args, options = extract_macro_options args, :role, :title, :with_sum

        project_id = args[0]
        user_roles = []

        if project_id.present?
          project_id.strip!

          project = Project.visible.find_by id: project_id
          project ||= Project.visible.find_by identifier: project_id
          project ||= Project.visible.find_by name: project_id
          return if project.nil?

          principals = project.visible_users
          return if principals.nil?

          users = []
          principals.each do |principal|
            next unless principal.type == 'User'

            user_roles[principal.id] = principal.roles_for_project project
            users << principal if options[:role].blank? || Additionals.check_role_matches(user_roles[principal.id], options[:role])
          end
        else
          users = User.visible
                      .where(type: 'User')
                      .active
                      .sorted
        end

        list_title = if options[:with_sum]
                       list_title = options[:title].presence || l(:label_member_plural)
                       list_title + " (#{users.count})"
                     else
                       options[:title]
                     end

        render partial: 'wiki/user_macros', locals: { users: users,
                                                      user_roles: user_roles,
                                                      list_title: list_title }
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
