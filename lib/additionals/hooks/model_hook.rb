# frozen_string_literal: true

module Additionals
  module Hooks
    class ModelHook < Redmine::Hook::Listener
      def after_plugins_loaded(_context = {})
        Additionals.setup!
      end
    end
  end
end
