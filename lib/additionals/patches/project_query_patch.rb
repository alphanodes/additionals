# frozen_string_literal: true

module Additionals
  module Patches
    module ProjectQueryPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def initialize_available_filters
          super
          return unless User.current.allowed_to? :edit_project, nil, global: true

          add_available_filter 'enable_new_ticket_message',
                               type: :list,
                               values: [[l(:label_system_setting), '1'],
                                        [l(:label_disabled), '0'],
                                        [l(:label_project_setting), '2']],
                               label: :label_new_ticket_message
        end
      end
    end
  end
end
