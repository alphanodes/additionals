module Additionals
  module Patches
    module AutoCompletesControllerPatch
      def fontawesome
        icons = AdditionalsFontAwesome.search_for_select(params[:q].to_s.strip,
                                                         params[:selected].to_s.strip)
        icons.sort! { |x, y| x[:text] <=> y[:text] }

        respond_to do |format|
          format.js { render json: icons }
          format.html { render json: icons }
        end
      end

      def issue_assignee
        scope = Principal.assignable_for_issues
        scope = scope.member_of(project) if @project.present?
        @assignee = scope.limit(100).distinct.sorted.like(params[:q]).to_a
        @assignee = @assignee.sort! { |x, y| x.name <=> y.name }
        render layout: false, partial: 'issue_assignee'
      end
    end
  end
end
