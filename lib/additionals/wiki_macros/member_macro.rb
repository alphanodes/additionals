# frozen_string_literal: true

module Additionals
  module WikiMacros
    module MemberMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display members.

    Syntax:

      {{members([PROJECT_NAME, title=My members list, role=ROLE, with_sum=BOOL)]}}

      PROJECT_NAME can be project identifier, project name or project id

    Parameters:

      :param string project_name: can be project identifier, project name or project id
      :param string title: title to use for member list
      :param string role: only list members with this role. If you want to use multiple roles as filters, you have to use a | as separator.
      :param bool with_sum: show amount of members.

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
            return unless project

            principals = project.visible_users
            return unless principals

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
                        .includes([:email_address])
                        .sorted
          end

          list_title = if options[:with_sum]
                         list_title = options[:title].presence || l(:label_member_plural)
                         list_title + " (#{users.count})"
                       else
                         options[:title]
                       end

          render 'wiki/user_macros', users: users,
                                     user_roles: user_roles,
                                     list_title: list_title
        end
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
