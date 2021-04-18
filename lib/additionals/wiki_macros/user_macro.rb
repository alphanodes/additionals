# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc "Display link to user profile\n\n" \
           "Syntax:\n\n" \
           "{{user(USER_NAME [, format=USER_FORMAT, text=BOOL], avatar=BOOL])}}\n\n" \
           "USER_NAME can be user id or user name (login name)\n" \
           "USER_FORMATS\n" \
           "- system (use system settings) (default)\n- " +
           User::USER_FORMATS.keys.join("\n- ") + "\n\n" \
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

        return if user.nil?

        name = if options[:format].blank?
                 user.name
               else
                 user.name options[:format].to_sym
               end

        s = []
        if options[:avatar].present? && options[:avatar]
          s << avatar(user, size: 14)
          s << ' '
        end

        link_css = "macro #{user.css_classes}"

        s << if user.active? && (options[:text].blank? || !options[:text])
               link_to h(name), user_url(user, only_path: controller_path != 'mailer'), class: link_css
             else
               tag.span h(name), class: link_css
             end
        safe_join s
      end
    end
  end
end
