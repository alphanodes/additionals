# frozen_string_literal: true

module Additionals
  module WikiMacros
    module MemberMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    Display members of a project, or all users if no project is given.

    Only users visible to the current user are listed, with avatar, login, email
    address (unless hidden) and, for a project, their roles. If the project does not
    exist or is not visible, a "not available" hint is shown.

    Syntax:

      {{members([PROJECT_NAME, title=TITLE, role=ROLE, with_sum=BOOL])}}

    Parameters:

      :param string project_name: project identifier, project name or project id
      :param string title: title of the member list
      :param string role: only list members with this role name (requires a project).
                          Separate multiple roles with |, e.g. role=Manager|Developer
      :param bool with_sum: show the number of members in the title (default title "Members")

    Examples:

      {{members}}
      ...List all active users visible to the current user

      {{members(with_sum=true)}}
      ...List all active users and show the number of users in the title

      {{members(the-identifier)}}
      ...List all members of the project with the identifier 'the-identifier'

      {{members(the-identifier, role=Manager)}}
      ...List all members of the project 'the-identifier' with the role "Manager"

      {{members(the-identifier, title=My user list)}}
      ...List all members of the project 'the-identifier' with title "My user list"
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
            return macro_not_available :label_project unless project

            principals = project.visible_users

            users = []
            principals.each do |principal|
              next unless principal.type == 'User'

              user_roles[principal.id] = principal.roles_for_project project
              users << principal if options[:role].blank? || Additionals.check_role_matches?(user_roles[principal.id], options[:role])
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

          render('wiki/user_macros', users:,
                                     user_roles:,
                                     list_title:)
        end
      end
    end
  end

  def self.check_role_matches?(roles, filters)
    filters.tr('|', ',').split(',').each do |filter|
      roles.each { |role| return true if filter.to_s == role.to_s }
    end
    false
  end
end
