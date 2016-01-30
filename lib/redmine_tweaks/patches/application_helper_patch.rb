# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2016 AlphaNodes GmbH

require_dependency 'application_helper'

module RedmineTweaks
  module Patches
    module ApplicationHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method_chain :parse_redmine_links, :tweaks

          def link_to_user_static(user, display, format, only_path)
            name = display || user.name(format)
            if user.active?
              # user_id = user.login.match(%r{^[a-z0-9_\-]+$}i) ? user.login.downcase : user
              link = link_to(h(name),
                             # { only_path: only_path, controller: 'users', action: 'show', id: user_id },
                             user_path(user),
                             class: user.css_classes)
            else
              link = h(name)
            end
            link
          end
        end
      end

      module InstanceMethods
        TWEAKS_USER_RE = %r{([\s\(,\-\[\>]|^)(!)?(([a-z0-9\-_]+):)?(user)(\(([^\)]+?)\)|\[([^\]]+?)\])?(?:(#)(\d+)|(:)([^"\s<>][^\s<>]*?|"[^"]+?"))(?=(?=[[:punct:]]\W)|,|\s|\]|<|$)}m

        def parse_redmine_links_with_tweaks(text, project, obj, attr, only_path, options)
          parse_redmine_links_without_tweaks(text, project, obj, attr, only_path, options)

          # Users:
          #   user#1 -> Link to user with id 1
          #   user:admin -> Link to user with username "admin"
          #   user:"admin" -> Link to user with username "admin"
          #   user(custom)#1 | user(user):admin -> Display "custom" instead of firstname and lastname
          #   user[f]#1 | user[f]:admin -> Display firstname
          text.gsub!(TWEAKS_USER_RE) do |m|
            leading, esc, project_prefix, project_identifier, prefix, option, display, format, sep, identifier = $1, $2, $3, $4, $5, $6, $7, $8, $9 || $11, $10 || $12
            link = nil
            if esc.nil?
              if project_identifier
                project = Project.visible.find_by_identifier(project_identifier)
              end
              if prefix == 'user' && format
                case format
                when 'fl'
                  format = 'firstname_lastname'
                when 'f'
                  format = 'firstname'
                when 'l'
                  format = 'lastname'
                when 'lf'
                  format = 'lastname_firstname'
                when 'u'
                  format = 'username'
                end
                format = format.to_sym
              end
              if sep == '#'
                oid = identifier.to_i
                case prefix
                when 'user'
                  if user = User.find_by_id(oid)
                    link = link_to_user_static(user, display, format, only_path)
                  end
                end
              elsif sep == ':'
                oname = identifier.gsub(%r{^"(.*)"$}, '\\1')
                case prefix
                when 'user'
                  if user = User.find_by_login(oname)
                    link = link_to_user_static(user, display, format, only_path)
                  end
                end
              end
            end
            leading + (link || "#{project_prefix}#{prefix}#{option}#{sep}#{identifier}")
          end
        end
      end
    end
  end
end

unless ApplicationHelper.included_modules.include?(RedmineTweaks::Patches::ApplicationHelperPatch)
  ApplicationHelper.send(:include, RedmineTweaks::Patches::ApplicationHelperPatch)
end
