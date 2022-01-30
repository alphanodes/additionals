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
          icons.sort! { |x, y| x[:text] <=> y[:text] }

          respond_to do |format|
            format.js { render json: icons }
            format.html { render json: icons }
          end
        end

        def issue_assignee
          scope = Principal.assignable_for_issues @project

          render_grouped_users_with_select2 scope, search_term: @search_term
        end

        def assignee
          scope = @project ? @project.principals : Principal.assignable

          render_grouped_users_with_select2 scope, search_term: @search_term
        end

        def authors
          scope = @project ? @project.users : User.visible

          render_grouped_users_with_select2 scope, search_term: @search_term, with_ano: true
        end

        # user and groups
        def grouped_principals
          scope = @project ? @project.principals : Principal.assignable

          render_grouped_users_with_select2 scope, search_term: @search_term, with_me: false
        end

        def grouped_users
          scope = @project ? @project.users : User.visible
          scope = scope.where.not id: params[:user_id] if params[:user_id].present?

          render_grouped_users_with_select2 scope, search_term: @search_term, with_me: false
        end

        private

        def find_search_term
          @search_term = build_search_query_term params
        end
      end
    end
  end
end
