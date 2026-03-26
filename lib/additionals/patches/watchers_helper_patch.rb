# frozen_string_literal: true

module Additionals
  module Patches
    module WatchersHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # OVERRIDE of WatchersHelper#watchers_list from Redmine Core
        # Based on: Redmine 6.1 (commit 9052d4d05 - #42589)
        # Source:   app/helpers/watchers_helper.rb
        #
        # Reason:   Filter watcher_users to hide members with hidden roles
        #           (Role#hide = true) from the watchers list. See #14191.
        #
        # Change:   Added AssignableUsersOptimizer.exclude_hidden_role_members
        #           filter after building the watcher scope.
        #
        # WARNING:  Must be kept in sync with Redmine Core!
        #           Check for upstream changes after each Redmine update.
        def watchers_list(object)
          remove_allowed = User.current.allowed_to? :"delete_#{object.class.name.underscore}_watchers", object.project
          content = ''.html_safe
          scope = Additionals::AssignableUsersOptimizer.exclude_hidden_role_members object.watcher_users, object.project
          scope = scope.includes(:email_address) if Setting.gravatar_enabled?
          scope.sorted.collect do |user|
            s = ''.html_safe
            s << avatar(user, size: '16').to_s if user.is_a? User
            s << link_to_principal(user, class: user.class.to_s.downcase)
            if object.respond_to?(:visible?) && user.is_a?(User) && !object.visible?(user)
              s << content_tag('span', sprite_icon('warning', l(:notice_invalid_watcher)),
                               class: 'icon-only icon-warning',
                               title: l(:notice_invalid_watcher))
            end
            if remove_allowed
              url = { controller: 'watchers',
                      action: 'destroy',
                      object_type: object.class.to_s.underscore,
                      object_id: object.id,
                      user_id: user }
              s << ' '
              s << link_to(sprite_icon('del', l(:button_delete)), url,
                           remote: true, method: 'delete',
                           class: 'delete icon-only icon-del',
                           title: l(:button_delete))
            end
            content << content_tag('li', s, class: "user-#{user.id}")
          end
          content.present? ? content_tag('ul', content, class: 'watchers') : content
        end
      end
    end
  end
end
