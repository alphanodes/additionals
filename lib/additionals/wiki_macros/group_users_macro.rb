# frozen_string_literal: true

module Additionals
  module WikiMacros
    module GroupUsersMacro
      Redmine::WikiFormatting::Macros.register do
        desc <<-DESCRIPTION
    List users of a group, with avatar, login and email address (unless hidden).

    Only groups and users visible to the current user are taken into account. If the
    group does not exist or is not visible, a "not available" hint is shown.

    Syntax:

      {{group_users(GROUP_NAME)}}

    Examples:

      {{group_users(Team A)}} - list users of group "Team A"
        DESCRIPTION

        macro :group_users do |_obj, args|
          raise 'The correct usage is {{group_users(<group_name>)}}' if args.empty?

          group_name = args[0].strip
          group = Group.visible.named(group_name).order(:id).first
          return macro_not_available :label_group unless group

          users = Principal.visible.where(id: group.users).order(User.name_formatter[:order])
          render partial: 'wiki/user_macros',
                 formats: [:html],
                 locals: { users:,
                           user_roles: nil,
                           list_title: group_name }
        end
      end
    end
  end
end
