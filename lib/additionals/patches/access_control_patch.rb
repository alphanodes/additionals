# frozen_string_literal: true

module Additionals
  module Patches
    module AccessControlPatch
      extend ActiveSupport::Concern

      class_methods do
        def available_project_modules_all
          @permissions.collect(&:project_module).compact!.uniq
        end

        def disabled_project_modules
          @database_ready = (RedminePluginKit::Loader.redmine_database_ready? Setting.table_name) unless defined? @database_ready
          return [] unless @database_ready

          mods = Additionals.setting(:disabled_modules).to_a.reject(&:blank?)
          mods.map(&:to_sym)
        end

        def active_entity_module?(klass)
          active_module? klass::ENTITY_MODULE_NAME.to_sym
        end

        def active_module?(mod)
          available_project_modules.include? mod
        end

        def disabled_module?(mod)
          disabled_project_modules.include? mod
        end
      end
    end

    module AccessControlClassPatch
      def available_project_modules
        super.reject { |m| disabled_project_modules.include? m }
      end

      # NOTE: This works for users and admin in projects
      # (but not in global context)
      def modules_permissions(modules)
        @modules_permissions ||= Hash.new do |h, key|
          key.reject! { |m| disabled_project_modules.include? m.to_sym }
          h[key] = super key
        end
        @modules_permissions[modules]
      end

      # TODO: this does not work probably
      # at the moment only elments are hidden, no permission is disabled for non-available module
      def permission_disabled(name)
        p = super
        return p if p.nil? || p.project_module.nil?

        p if available_project_modules.include? p.project_module
      end
    end
  end
end
