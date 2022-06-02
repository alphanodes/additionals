# frozen_string_literal: true

module Additionals
  module Patches
    module ReportsControllerPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def issue_report_details
          super
          return unless @rows

          if Setting.issue_group_assignment? && params[:detail] == 'assigned_to'
            @rows = @project.visible_principals + [User.new(firstname: "[#{l :label_none}]")]
          elsif params[:detail] == 'assigned_to'
            @rows = @project.visible_users + [User.new(firstname: "[#{l :label_none}]")]
          elsif params[:detail] == 'author'
            @rows = @project.visible_users
          end
        end
      end
    end
  end
end
