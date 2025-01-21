# frozen_string_literal: true

module ControllerWithQuery
  extend ActiveSupport::Concern

  included do |base|
    # NOTE: set it to queried class, this is required for all methods!
    base.class_attribute :queried_class_name

    rescue_from Query::StatementInvalid, with: :query_statement_invalid

    helper :queries
    helper :additionals_queries

    # NOTE: order of includes matters for query helpers (required for csv)
    include QueriesHelper
    include AdditionalsQueriesHelper
  end

  def additionals_query_class
    Object.const_get :"#{queried_class_name.to_s.camelcase}Query"
  end

  def additionals_retrieve_query(user_filter: nil, search_string: nil)
    session_key = additionals_query_session_key
    query_class = additionals_query_class

    if params[:query_id].present?
      additionals_load_query_id(query_class,
                                session_key,
                                params[:query_id],
                                user_filter:,
                                search_string:)
    elsif api_request? ||
          params[:set_filter] ||
          session[session_key].nil? ||
          session[session_key][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = query_class.new name: '_', project: @project
      @query.project = @project
      @query.user_filter = user_filter if user_filter
      @query.search_string = search_string if search_string
      @query.build_from_params params
      session[session_key] = { project_id: @query.project_id }
      # session has a limit to 4k, we have to use a cache for it for larger data
      Rails.cache.write(additionals_query_cache_key,
                        filters: @query.filters,
                        group_by: @query.group_by,
                        column_names: @query.column_names,
                        totalable_names: @query.totalable_names,
                        sort_criteria: params[:sort].presence || @query.sort_criteria.to_a)
    else
      # retrieve from session
      @query = query_class.find_by id: session[session_key][:id] if session[session_key][:id]
      session_data = Rails.cache.read additionals_query_cache_key
      @query ||= query_class.new(name: '_',
                                 project: @project,
                                 filters: session_data.nil? ? nil : session_data[:filters],
                                 group_by: session_data.nil? ? nil : session_data[:group_by],
                                 column_names: session_data.nil? ? nil : session_data[:column_names],
                                 totalable_names: session_data.nil? ? nil : session_data[:totalable_names],
                                 sort_criteria: params[:sort].presence || (session_data.nil? ? nil : session_data[:sort_criteria]))
      @query.project = @project
      @query.user_filter = user_filter if user_filter
      @query.display_type = params[:display_type] if params[:display_type]

      if params[:sort].present?
        @query.sort_criteria = params[:sort]
        # we have to write cache for sort order
        Rails.cache.write(additionals_query_cache_key,
                          filters: @query.filters,
                          group_by: @query.group_by,
                          column_names: @query.column_names,
                          totalable_names: @query.totalable_names,
                          sort_criteria: params[:sort])
      elsif session_data.present?
        @query.sort_criteria = session_data[:sort_criteria]
      end
    end
  end

  def query_statement_invalid(exception)
    Rails.logger.error "Query::StatementInvalid: #{exception.message}"
    session.delete additionals_query_session_key
    render_error l(:error_query_statement_invalid)
  end

  private

  def additionals_query_session_key
    :"#{queried_class_name}_query"
  end

  def additionals_load_query_id(query_class, session_key, query_id, user_filter: nil, search_string: nil)
    scope = query_class.where project_id: nil
    scope = scope.or query_class.where(project_id: @project) if @project
    @query = scope.find query_id
    raise ::Unauthorized unless @query.visible?

    @query.project = @project
    @query.user_filter = user_filter if user_filter
    @query.search_string = search_string if search_string
    session[session_key] = { id: @query.id, project_id: @query.project_id }

    @query.sort_criteria = params[:sort] if params[:sort].present?
    # we have to write cache for sort order
    Rails.cache.write(additionals_query_cache_key,
                      filters: @query.filters,
                      group_by: @query.group_by,
                      column_names: @query.column_names,
                      totalable_names: @query.totalable_names,
                      sort_criteria: @query.sort_criteria)
  end

  def additionals_query_cache_key
    project_id = @project ? @project.id : 0
    "#{queried_class_name}_query_data_#{session.id}_#{project_id}"
  end
end
