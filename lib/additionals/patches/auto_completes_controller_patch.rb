# frozen_string_literal: true

module Additionals
  module Patches
    module AutoCompletesControllerPatch
      extend ActiveSupport::Concern

      included do
        include AdditionalsQueriesHelper
        include AdditionalsIconsHelper
        include InstanceMethods

        before_action :find_search_term
      end

      module InstanceMethods
        def fontawesome
          icons = AdditionalsFontAwesome.search_for_select @search_term, params[:selected].to_s.strip
          icons.sort_by! { |a| a[:text] }

          respond_to do |format|
            format.json { render json: icons }
            format.html { render json: icons }
          end
        end

        def issue_assignee
          scope = Principal.assignable_for_issues @project

          render_params = { search_term: @search_term }
          render_params[:with_me] = RedminePluginKit.true? params[:with_me] if params.key? :with_me

          if params[:issue_id].present?
            issue = Issue.find_by id: params[:issue_id]
            render_params[:involved_principals] = issue_involved_principals(issue) if issue
          end

          render_grouped_users_with_select2(scope, use_assignment_frequency: true, apply_assignee_format: true, **render_params)
        end

        def assignee
          scope = @project ? @project.assignable_principals.visible : Principal.assignable

          render_grouped_users_with_select2 scope, search_term: @search_term, use_assignment_frequency: true,
                                                   apply_assignee_format: true
        end

        def authors
          scope = @project ? @project.users.visible : User.active.visible

          render_grouped_users_with_select2 scope, search_term: @search_term
        end

        def custom_field_users
          cf = CustomField.find_by id: params[:custom_field_id]
          return render json: [] unless cf

          scope = custom_field_users_scope cf
          return render json: [] if scope.nil?

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
                            with_me: RedminePluginKit.true?(params[:with_me]),
                            # Assignee ordering only when the caller flags an assignee context
                            # (e.g. entity assigned_to selects); watcher/plain principal picks omit it.
                            apply_assignee_format: RedminePluginKit.true?(params[:assignee_format]) }
          render_params[:me_value] = params[:me_value] if params.key? :me_value

          render_grouped_users_with_select2(scope, **render_params)
        end

        private

        # Mirrors the user scope of Additionals::Patches::UserFormatPatch#possible_values_records
        # so the select2 AJAX suggestions match the plain <select> options:
        #   '1' => all visible users (incl. locked), '4' => all active visible users,
        #   else => project members (optionally narrowed by the configured roles).
        # Returns nil when the project-based scopes are requested without a project.
        def custom_field_users_scope(custom_field)
          case custom_field.user_scope.to_s
          when '1' then User.visible
          when '4' then User.active.visible
          else
            return unless @project

            scope = @project.users.visible
            role_ids = custom_field.user_role.is_a?(Array) ? custom_field.user_role.map(&:to_s).compact_blank.map(&:to_i) : []
            return scope if role_ids.empty?

            scope.where "#{Member.table_name}.id IN (SELECT DISTINCT member_id" \
                        " FROM #{MemberRole.table_name} WHERE role_id IN (?))", role_ids
          end
        end

        def find_search_term
          @search_term = build_search_query_term params
        end

        def issue_involved_principals(issue)
          principals = [issue.author, issue.prior_assigned_to].uniq
          principals.compact!
          principals.select { |p| @search_term.blank? || p.name.downcase.include?(@search_term.downcase) }
        end
      end
    end
  end
end
