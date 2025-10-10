# frozen_string_literal: true

module Additionals
  # This module provides role-based visibility for custom fields on entities.
  # It must be included AFTER acts_as_customizable to properly override the
  # default visible_custom_field_values method.
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
