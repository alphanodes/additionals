# frozen_string_literal: true

module Additionals
  module Patches
    module UserFormatPatch
      extend ActiveSupport::Concern

      included do
        # Adds a configurable user scope to the core "user" custom field format.
        # Core only ever lists project members, which is useless for entities
        # where the assigned user is usually not a project member (e.g. a
        # customer login assigned to a contact or database entry).
        #
        # user_scope values:
        #   '1' => all visible users (incl. locked - e.g. expired customer logins)
        #   '4' => all active visible users
        #   '2' / '3' / nil => core behaviour (project members, optionally by role)
        field_attributes :user_scope

        # Replace the core user form partial with our own that adds the scope
        # selector. Using form_partial (not a Deface override) avoids duplicated
        # rendering and keeps the f/custom_field locals Redmine passes in.
        self.form_partial = 'custom_fields/formats/additionals_user'

        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def possible_values_records(custom_field, object = nil)
          return super if object.is_a? Array

          case custom_field.user_scope.to_s
          when '1' then User.visible.sorted
          when '4' then User.active.visible.sorted
          else super
          end
        end

        def query_filter_values(custom_field, query)
          scope = case custom_field.user_scope.to_s
                  when '1' then User.visible
                  when '4' then User.active.visible
                  else return super
                  end

          values = []
          values << ["<< #{l :label_me} >>", 'me'] if User.current.logged?
          values + scope.sorted.map { |u| [u.name, u.id.to_s, l("status_#{User::LABEL_BY_STATUS[u.status]}")] }
        end
      end
    end
  end
end
