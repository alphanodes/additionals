# frozen_string_literal: true

module Additionals
  # This module provides role-based visibility for custom fields on entities.
  # It must be included AFTER acts_as_customizable to properly override the
  # default visible_custom_field_values method.
  #
  # This fixes bug #14192 where custom fields with role restrictions are visible
  # to all users instead of only users with matching roles.
  #
  # Usage in entity models (AFTER acts_as_customizable):
  #   class MyEntity < ApplicationRecord
  #     acts_as_customizable
  #     include Additionals::EntityCustomFieldVisibility
  #   end
  #
  # For entities with multiple projects (like Contact), override visible_custom_field_values
  # to check visibility in ANY of the entity's projects.
  module EntityCustomFieldVisibility
    extend ActiveSupport::Concern

    # Override default acts_as_customizable implementation to check role-based visibility
    # like Issue does. This assumes the entity has a single `project` association.
    #
    # Entities with multiple projects (like Contact) should override this method
    # to check visibility across all their projects.
    #
    # @param user [User, nil] The user to check visibility for (defaults to User.current)
    # @return [Array<CustomFieldValue>] Custom field values visible to the user
    # @see Issue#visible_custom_field_values
    def visible_custom_field_values(user = nil)
      user_real = user || User.current
      custom_field_values.select do |value|
        value.custom_field.visible_by? project, user_real
      end
    end

    # Returns custom field values that are both visible and editable by the user.
    # Filters by role-based visibility AND the custom field's editable? flag.
    #
    # For entities without locked/closed status (unlike Issue), all visible fields
    # are editable unless the custom field itself is marked as non-editable.
    #
    # @param user [User, nil] The user to check editability for (defaults to User.current)
    # @return [Array<CustomFieldValue>] Custom field values editable by the user
    # @see Issue#editable_custom_field_values
    def editable_custom_field_values(user = nil)
      visible_custom_field_values(user).select(&:editable?)
    end
  end
end
