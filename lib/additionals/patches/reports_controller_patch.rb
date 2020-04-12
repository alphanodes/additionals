module Additionals
  module Patches
    module ReportsControllerPatch
      def self.included(base)
        base.prepend InstancOverwriteMethods
      end

      module InstancOverwriteMethods
        def issue_report_details
          super
          return if @rows.nil?

          if Setting.issue_group_assignment? && params[:detail] == 'assigned_to'
            @rows = @project.visible_principals
          elsif %w[assigned_to author].include? params[:detail]
            @rows = @project.visible_users
          end
        end
      end
    end
  end
end
