# frozen_string_literal: true

module Additionals
  module Patches
    # Pipe Redmine-Core helpers that build a project list outside of
    # `Project.visible` through `Project.listable` so other plugins can
    # subtract certain project kinds from those listings (see the
    # canonical `Project.listable` scope in `project_patch.rb`).
    module ApplicationHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def projects_for_jump_box(user = User.current)
          return [] unless user.logged?

          user.projects.active
              .merge(Project.listable)
              .select(:id, :name, :identifier, :lft, :rgt)
              .to_a
        end
      end
    end
  end
end
