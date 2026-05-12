# frozen_string_literal: true

require_dependency 'admin_controller'

module Additionals
  module Patches
    module AdminControllerPatch
      extend ActiveSupport::Concern

      included do
        # AdminController#projects renders projects/_list.html.erb, which
        # may include columns added by other plugins through QueriesHelper
        # patches. Those patches frequently call helpers defined in
        # AdditionalsQueriesHelper (e.g. link_to_nonzero) — make them
        # available here so the column renderers do not crash.
        helper :additionals_queries
      end
    end
  end
end
