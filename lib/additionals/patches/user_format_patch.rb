# frozen_string_literal: true

module Additionals
  module Patches
    module UserFormatPatch
      extend ActiveSupport::Concern

      included do
        # Adds a configurable user scope to the core "user" custom field format.
        # Core only ever lists project members, which is useless for entities
        # where the assigned user is usually not a project member.
        #
        # user_scope values:
        #   '1' => all visible users, locked ones included
        #   '4' => all active visible users
        #   '2' / '3' / nil => core behaviour (project members, optionally by role)
        field_attributes :user_scope

        # The scope is offered only for the entities a plugin registers here,
        # like customized_class_names. User fields of all other entities keep
        # the core form and behaviour.
        class_attribute :user_scope_class_names
        self.user_scope_class_names = []

        format = self
        CustomField.safe_attributes 'user_scope', if: ->(custom_field, _user) { format.user_scope_for? custom_field }

        # Replace the core user form partial with our own that adds the scope
        # selector. Using form_partial (not a Deface override) avoids duplicated
        # rendering and keeps the f/custom_field locals Redmine passes in.
        self.form_partial = 'custom_fields/formats/additionals_user'

        include InstanceMethods
        prepend InstanceOverwriteMethods
      end

      class_methods do
        def user_scope_for?(custom_field)
          user_scope_class_names.include? custom_field.class.customized_class&.name
        end
      end

      module InstanceMethods
        # Redmine 7.1 can offer groups in user custom fields (https://www.redmine.org/issues/21026), Redmine 7.0 users only
        # TODO(Redmine 7.0 EOL): call selectable_principal_types directly.
        def additionals_principal_types(custom_field)
          respond_to?(:selectable_principal_types) ? selectable_principal_types(custom_field) : %w[User]
        end

        # Principals of the project independent user scopes '1' and '4',
        # nil for the project-based scopes handled by core
        def additionals_scope_principals(custom_field)
          return unless self.class.user_scope_for? custom_field

          scope = case custom_field.user_scope.to_s
                  when '1' then Principal.visible
                  when '4' then Principal.active.visible
                  else return
                  end

          scope.where type: additionals_principal_types(custom_field)
        end
      end

      module InstanceOverwriteMethods
        def possible_values_records(custom_field, object = nil)
          return super if object.is_a? Array

          principals = additionals_scope_principals custom_field
          principals ? principals.sorted : super
        end

        def query_filter_values(custom_field, query)
          principals = additionals_scope_principals custom_field
          return super unless principals

          values = []
          values << ["<< #{l :label_me} >>", 'me'] if User.current.logged?
          values + principals.sorted.map { |p| [p.name, p.id.to_s, l("status_#{User::LABEL_BY_STATUS[p.status]}")] }
        end
      end
    end
  end
end
