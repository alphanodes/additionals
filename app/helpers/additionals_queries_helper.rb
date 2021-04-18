# frozen_string_literal: true

module AdditionalsQueriesHelper
  def additionals_query_session_key(object_type)
    "#{object_type}_query".to_sym
  end

  def additionals_retrieve_query(object_type, user_filter: nil)
    session_key = additionals_query_session_key object_type
    query_class = Object.const_get "#{object_type.camelcase}Query"
    if params[:query_id].present?
      additionals_load_query_id query_class,
                                session_key,
                                params[:query_id],
                                object_type,
                                user_filter: user_filter
    elsif api_request? ||
          params[:set_filter] ||
          session[session_key].nil? ||
          session[session_key][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = query_class.new name: '_'
      @query.project = @project
      @query.user_filter = user_filter if user_filter
      @query.build_from_params params
      session[session_key] = { project_id: @query.project_id }
      # session has a limit to 4k, we have to use a cache for it for larger data
      Rails.cache.write(additionals_query_cache_key(object_type),
                        filters: @query.filters,
                        group_by: @query.group_by,
                        column_names: @query.column_names,
                        totalable_names: @query.totalable_names,
                        sort_criteria: params[:sort].presence || @query.sort_criteria.to_a)
    else
      # retrieve from session
      @query = query_class.find_by id: session[session_key][:id] if session[session_key][:id]
      session_data = Rails.cache.read additionals_query_cache_key(object_type)
      @query ||= query_class.new(name: '_',
                                 filters: session_data.nil? ? nil : session_data[:filters],
                                 group_by: session_data.nil? ? nil : session_data[:group_by],
                                 column_names: session_data.nil? ? nil : session_data[:column_names],
                                 totalable_names: session_data.nil? ? nil : session_data[:totalable_names],
                                 sort_criteria: params[:sort].presence || (session_data.nil? ? nil : session_data[:sort_criteria]))
      @query.project = @project
      if params[:sort].present?
        @query.sort_criteria = params[:sort]
        # we have to write cache for sort order
        Rails.cache.write(additionals_query_cache_key(object_type),
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

  def additionals_load_query_id(query_class, session_key, query_id, object_type, user_filter: nil)
    scope = query_class.where project_id: nil
    scope = scope.or query_class.where(project_id: @project.id) if @project
    @query = scope.find query_id
    raise ::Unauthorized unless @query.visible?

    @query.project = @project
    @query.user_filter = user_filter if user_filter
    session[session_key] = { id: @query.id, project_id: @query.project_id }

    @query.sort_criteria = params[:sort] if params[:sort].present?
    # we have to write cache for sort order
    Rails.cache.write(additionals_query_cache_key(object_type),
                      filters: @query.filters,
                      group_by: @query.group_by,
                      column_names: @query.column_names,
                      totalable_names: @query.totalable_names,
                      sort_criteria: @query.sort_criteria)
  end

  def additionals_query_cache_key(object_type)
    project_id = @project ? @project.id : 0
    "#{object_type}_query_data_#{session.id}_#{project_id}"
  end

  def additionals_select2_search_users(all_visible: false, where_filter: nil, where_params: nil)
    q = params[:q].to_s.strip
    exclude_id = params[:user_id].to_i
    scope = User.active.where type: 'User'
    scope = scope.visible unless all_visible
    scope = scope.where.not id: exclude_id if exclude_id.positive?
    scope = scope.where where_filter, where_params if where_filter
    q.split.map { |search_string| scope = scope.like search_string } if q.present?
    scope = scope.order(last_login_on: :desc)
                 .limit(Additionals::SELECT2_INIT_ENTRIES)
    @users = scope.to_a.sort! { |x, y| x.name <=> y.name }
    render layout: false, partial: 'auto_completes/additionals_users'
  end

  def additionals_query_to_xlsx(items, query, no_id_link: false)
    require 'write_xlsx'

    options = { no_id_link: no_id_link,
                filename: StringIO.new(+'') }

    export_to_xlsx items, query.columns, options
    options[:filename].string
  end

  def additionals_result_to_xlsx(items, columns, options)
    raise 'option filename is mission' if options[:filename].blank?

    require 'write_xlsx'
    export_to_xlsx items, columns, options
  end

  def export_to_xlsx(items, columns, options)
    workbook = WriteXLSX.new options[:filename]
    worksheet = workbook.add_worksheet

    # Freeze header row and # column.
    freeze_row = options[:freeze_first_row].nil? || options[:freeze_first_row] ? 1 : 0
    freeze_column = options[:freeze_first_column].nil? || options[:freeze_first_column] ? 1 : 0
    worksheet.freeze_panes freeze_row, freeze_column

    options[:columns_width] = if options[:xlsx_write_header_row].present?
                                send options[:xlsx_write_header_row], workbook, worksheet, columns
                              else
                                xlsx_write_header_row workbook, worksheet, columns
                              end
    options[:columns_width] = if options[:xlsx_write_item_rows].present?
                                send options[:xlsx_write_item_rows], workbook, worksheet, columns, items, options
                              else
                                xlsx_write_item_rows workbook, worksheet, columns, items, options
                              end
    columns.size.times do |index|
      worksheet.set_column index, index, options[:columns_width][index]
    end

    workbook.close
  end

  def xlsx_write_header_row(workbook, worksheet, columns)
    columns_width = []
    columns.each_with_index do |c, index|
      value = if c.is_a? String
                c
              else
                c.caption.to_s
              end

      worksheet.write 0, index, value, workbook.add_format(xlsx_cell_format(:header))
      columns_width << xlsx_get_column_width(value)
    end
    columns_width
  end

  def xlsx_write_item_rows(workbook, worksheet, columns, items, options)
    hyperlink_format = workbook.add_format xlsx_cell_format(:link)
    even_text_format = workbook.add_format xlsx_cell_format(:text, '', 0)
    even_text_format.set_num_format 0x31
    odd_text_format = workbook.add_format xlsx_cell_format(:text, '', 1)
    odd_text_format.set_num_format 0x31

    items.each_with_index do |line, line_index|
      columns.each_with_index do |c, column_index|
        value = csv_content(c, line).dup
        if c.name == :id # ID
          if options[:no_id_link].blank?
            link = url_for controller: line.class.name.underscore.pluralize, action: 'show', id: line.id
            worksheet.write line_index + 1, column_index, link, hyperlink_format, value
          else
            # id without link
            worksheet.write(line_index + 1,
                            column_index,
                            value,
                            workbook.add_format(xlsx_cell_format(:cell, value, line_index)))
          end
        elsif xlsx_hyperlink_cell? value
          worksheet.write line_index + 1, column_index, value[0..254], hyperlink_format, value
        elsif !c.inline?
          # block column can be multiline strings
          value.gsub! "\r\n", "\n"
          text_format = line_index.even? ? even_text_format : odd_text_format
          worksheet.write_rich_string line_index + 1, column_index, value, text_format
        else
          worksheet.write(line_index + 1,
                          column_index,
                          value,
                          workbook.add_format(xlsx_cell_format(:cell, value, line_index)))
        end

        width = xlsx_get_column_width value
        options[:columns_width][column_index] = width if options[:columns_width][column_index] < width
      end
    end
    options[:columns_width]
  end

  def xlsx_get_column_width(value)
    value_str = value.to_s

    # 1.1: margin
    width = (value_str.length + value_str.chars.count { |e| !e.ascii_only? }) * 1.1 + 1
    # 30: max width
    width > 30 ? 30 : width
  end

  def xlsx_cell_format(type, value = 0, index = 0)
    format = { border: 1, text_wrap: 1, valign: 'top' }
    case type
    when :header
      format[:bold] = 1
      format[:color] = 'white'
      format[:bg_color] = 'gray'
    when :link
      format[:color] = 'blue'
      format[:underline] = 1
      format[:bg_color] = 'silver' unless index.even?
    else
      format[:bg_color] = 'silver' unless index.even?
      format[:color] = 'red' if value.is_a?(Numeric) && value.negative?
    end

    format
  end

  def xlsx_hyperlink_cell?(token)
    # Match http, https or ftp URL
    if %r{\A[fh]tt?ps?://}.match?(token) ||
       # Match mailto:
       token.present? && token.start_with?('mailto:') ||
       # Match internal or external sheet link
       /\A(?:in|ex)ternal:/.match?(token)
      true
    end
  end

  # Returns the query definition as hidden field tags
  # columns in ignored_column_names are skipped (names as symbols)
  # TODO: this is a temporary fix and should be removed
  # after https://www.redmine.org/issues/29830 is in Redmine core.
  def query_as_hidden_field_tags(query)
    tags = hidden_field_tag 'set_filter', '1', id: nil

    if query.filters.present?
      query.filters.each do |field, filter|
        tags << hidden_field_tag('f[]', field, id: nil)
        tags << hidden_field_tag("op[#{field}]", filter[:operator], id: nil)
        filter[:values].each do |value|
          tags << hidden_field_tag("v[#{field}][]", value, id: nil)
        end
      end
    else
      tags << hidden_field_tag('f[]', '', id: nil)
    end

    ignored_block_columns = query.block_columns.map(&:name)
    query.columns.each do |column|
      next if ignored_block_columns.include? column.name

      tags << hidden_field_tag('c[]', column.name, id: nil)
    end
    if query.totalable_names.present?
      query.totalable_names.each do |name|
        tags << hidden_field_tag('t[]', name, id: nil)
      end
    end
    tags << hidden_field_tag('group_by', query.group_by, id: nil) if query.group_by.present?
    tags << hidden_field_tag('sort', query.sort_criteria.to_param, id: nil) if query.sort_criteria.present?

    tags
  end

  def render_query_group_view(query, locals = {})
    return if locals[:group_name].blank?

    render partial: 'queries/additionals_group_view',
           locals: { query: query }.merge(locals)
  end
end
