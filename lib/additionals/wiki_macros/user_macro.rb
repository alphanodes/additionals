# frozen_string_literal: true

module Additionals
  module WikiMacros
    module UserMacro
      Redmine::WikiFormatting::Macros.register do
        desc "Display link to user profile\n\n" \
             "Syntax:\n\n" \
             "{{user(USER_NAME [, format=USER_FORMAT, avatar=BOOL, text=BOOL])}}\n\n" \
             "USER_NAME can be user id, user name (login name) or current_user\n" \
             "USER_FORMAT (system or omitted uses the system setting)\n- system\n- " \
             "#{User::USER_FORMATS.keys.join "\n- "}\n\n" \
             "avatar=true shows the avatar, text=true shows the name without link.\n" \
             'Locked users are shown without link. If the user does not exist, ' \
             "a \"not available\" hint is shown.\n\n" \
             "Examples:\n\n" \
             "{{user(1)}}\n" \
             "...Link to user with user id 1\n\n" \
             "{{user(1, avatar=true)}}\n" \
             "...Link to user with user id 1 with avatar\n\n" \
             "{{user(current_user, text=true)}}\n" \
             "...Show only user (without link) of the current user\n\n" \
             "{{user(admin)}}\n" \
             "...Link to user with username 'admin'\n\n" \
             "{{user(admin, format=firstname)}}\n" \
             "...Link to user with username 'admin' and show firstname as link text"

        macro :user do |_obj, args|
          args, options = extract_macro_options args, :format, :avatar, :text
          raise 'The correct usage is {{user(<user_id or username>, format=USER_FORMAT)}}' if args.empty?

          user_id = args[0]

          user = User.find_by id: user_id
          user ||= if user_id == 'current_user'
                     User.current
                   else
                     User.find_by login: user_id
                   end

          return macro_not_available :label_user unless user

          name = if options[:format].blank? || options[:format] == 'system'
                   user.name
                 else
                   user.name options[:format].to_sym
                 end

          s = []
          if RedminePluginKit.true? options[:avatar]
            s << avatar(user, size: 14)
            s << ' '
          end

          link_css = "macro #{user.css_classes}"

          s << if user.active? && RedminePluginKit.false?(options[:text])
                 link_to h(name), user_url(user, only_path: controller_path != 'mailer'), class: link_css
               else
                 tag.span h(name), class: link_css
               end
          safe_join s
        end
      end
    end
  end
end
