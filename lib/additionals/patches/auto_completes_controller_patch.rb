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
        assignee_classes = ['User']
        assignee_classes << 'Group' if Setting.issue_group_assignment?

        scope = Principal.where(type: assignee_classes).limit(100)
        scope = scope.member_of(project) if @project.present?
        scope = scope.distinct
        @assignee = scope.active.visible.sorted.like(params[:q]).to_a
        @assignee = @assignee.sort! { |x, y| x.name <=> y.name }
        render layout: false, partial: 'issue_assignee'
      end
    end
  end
end
