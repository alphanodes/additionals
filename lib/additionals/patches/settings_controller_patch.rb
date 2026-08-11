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
        # The stored settings arrive as a HashWithIndifferentAccess (string keys, read
        # by either spelling), while the defaults of the plugin loader use symbols.
        # Both parts of this line matter: reverse_merge adds only the missing keys and
        # never overwrites a stored value, and with_indifferent_access keeps symbol
        # access working. Merging the other way round (defaults.merge settings) returns
        # an ordinary hash carrying every key twice, where a lookup by symbol finds the
        # empty default instead of the stored value.
        def plugin
          super

          return if performed? || @settings.blank?

          defaults = @plugin.settings[:default]
          return unless defaults.is_a? Hash

          @settings = @settings.with_indifferent_access.reverse_merge defaults
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
