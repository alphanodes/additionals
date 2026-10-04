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

        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # Redmine core (since 7.1) checks for a mermaid library installed with
        # redmine:mermaid:install, but renders mermaid code blocks with the one
        # bundled in additionals (see additionals/_html_head).
        def info
          super
          mermaid = @checklist.assoc :text_mermaid_available
          mermaid[1] = true if mermaid
        end
      end
    end
  end
end
