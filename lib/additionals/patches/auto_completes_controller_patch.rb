# frozen_string_literal: true

module Additionals
  module Patches
    module AutoCompletesControllerPatch
      def fontawesome
        icons = AdditionalsFontAwesome.search_for_select params[:q].to_s.strip,
                                                         params[:selected].to_s.strip
        icons.sort! { |x, y| x[:text] <=> y[:text] }

        respond_to do |format|
          format.js { render json: icons }
          format.html { render json: icons }
        end
      end

      def global_users
        scope = Principal.assignable
        @assignee = scope.like(params[:q]).sorted.limit(100).to_a
        render layout: false, partial: 'issue_assignee'
      end

      def issue_assignee
        scope = Principal.assignable_for_issues @project
        @assignee = scope.like(params[:q]).sorted.limit(100).to_a
        render layout: false, partial: 'issue_assignee'
      end
    end
  end
end
