# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GroupUsersMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    List users of a user group (according the respective permissions)

    Syntax:

      {{group_users(GROUP_NAME}}

    Examples:

      {{group_users(Team A)}} - list users of group "Team A"
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
end
