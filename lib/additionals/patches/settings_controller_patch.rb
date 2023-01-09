# frozen_string_literal: true

module Additionals
  module Patches
    module SettingsControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods

        helper :additionals_settings
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
