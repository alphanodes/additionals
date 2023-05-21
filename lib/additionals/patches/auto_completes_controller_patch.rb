# frozen_string_literal: true

module Additionals
  module Patches
    module AutoCompletesControllerPatch
      extend ActiveSupport::Concern

      included do
        include AdditionalsQueriesHelper
        include InstanceMethods

        before_action :find_search_term
      end

      module InstanceMethods
        def fontawesome
          icons = AdditionalsFontAwesome.search_for_select @search_term, params[:selected].to_s.strip
          icons.sort_by! { |a| a[:text] }

          respond_to do |format|
            format.js { render json: icons }
            format.html { render json: icons }
          end
        end

        def issue_assignee
          scope = Principal.assignable_for_issues @project

          render_params = { search_term: @search_term }
          render_params[:with_me] = RedminePluginKit.true? params[:with_me] if params.key? :with_me

          render_grouped_users_with_select2(scope, **render_params)
        end

        def assignee
          scope = @project ? @project.assignable_principals.visible : Principal.assignable

          render_grouped_users_with_select2 scope, search_term: @search_term
        end

        def grouped_users
          scope = @project ? @project.users.visible : User.visible
          scope = scope.where.not id: params[:user_id] if params[:user_id].present?
          scope = scope.active if RedminePluginKit.true? params[:active_only]

          render_params = { search_term: @search_term,
                            with_ano: RedminePluginKit.true?(params[:with_ano]),
                            with_me: RedminePluginKit.true?(params[:with_me]) }
          render_params[:me_value] = params[:me_value] if params.key? :me_value

          render_grouped_users_with_select2(scope, **render_params)
        end

        # user and groups
        def grouped_principals
          scope = @project ? @project.assignable_principals.visible : Principal.assignable

          render_params = { search_term: @search_term,
                            with_me: RedminePluginKit.true?(params[:with_me]) }
          render_params[:me_value] = params[:me_value] if params.key? :me_value

          render_grouped_users_with_select2(scope, **render_params)
        end

        private

        def find_search_term
          @search_term = build_search_query_term params
        end
      end
    end
  end
end
