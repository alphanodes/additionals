# frozen_string_literal: true

module Additionals
  module Patches
    module SettingsControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
        prepend InstanceOverwriteMethods

        helper :additionals_settings
      end

      module InstanceOverwriteMethods
        # Redmine keeps the settings of a plugin in a single hash and replaces it as a
        # whole when the form is saved. A setting introduced by a plugin update is
        # therefore missing from the stored hash of every installation that ever saved
        # the form, and the form renders it as empty or off although the default is
        # what actually applies. A required field is worse than cosmetic there: it
        # blocks saving the tab at all.
        #
        # Filled in here and not in the settings helpers, because views also read
        # @settings directly.
        def plugin
          super

          return if performed? || @settings.blank?

          defaults = @plugin.settings[:default]
          @settings = defaults.merge @settings if defaults.is_a? Hash
        end
      end

      module InstanceMethods
        def plugin_settings_path(plugin, options = nil)
          options ||= {}
          options[:tab] = params[:tab] if params[:tab] && !options.key?(:tab)
          options[:filter] = params[:filter] if params[:filter] && !options.key?(:filter)

          super(plugin, **options)
        end
      end
    end
  end
end
