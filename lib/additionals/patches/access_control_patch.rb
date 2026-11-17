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
          return [] unless settings_table_ready?

          mods = Additionals.setting(:disabled_modules).to_a.compact_blank
          mods.map(&:to_sym)
        end

        def active_entity_module?(klass)
          active_module? klass::ENTITY_MODULE_NAME.to_sym
        end

        # Without the settings table (db:create, db:migrate) no setting disables
        # a module, and patches of available_project_modules by other plugins
        # may read settings, which would stop the boot
        def active_module?(mod)
          return available_project_modules_all.include? mod unless settings_table_ready?

          available_project_modules.include? mod
        end

        def settings_table_ready?
          @settings_table_ready = RedminePluginKit::Loader.redmine_database_ready? Setting.table_name unless defined? @settings_table_ready
          @settings_table_ready
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

      # Disabled modules give no permissions in projects, for users and admins
      # (not in global context). Not cached, a lock applies at once and in all
      # processes; Redmine remembers the permissions of a project per request.
      def modules_permissions(modules)
        disabled = disabled_project_modules.map(&:to_s)
        super(modules.reject { |mod| disabled.include? mod.to_s })
      end
    end
  end
end
