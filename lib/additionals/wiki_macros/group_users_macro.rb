# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Display users of group.

  Syntax:

    {{group_users(GROUP_NAME}}

  Examples:

    {{group_users(Team)}}
    ...List all users in user group "Team" (with the current user permission)
      DESCRIPTION

      macro :group_users do |_obj, args|
        raise 'The correct usage is {{group_users(<group_name>)}}' if args.empty?

        group_name = args[0].strip
        group = Group.named(group_name).first
        raise unless group

        users = Principal.visible.where(id: group.users).order(User.name_formatter[:order])
        render partial: 'wiki/user_macros',
               formats: [:html],
               locals: { users: users,
                         user_roles: nil,
                         list_title: group_name }
      end
    end
  end
end
