module AdditionalsQueryHelper
  def additionals_select2_search_users(where_filter = '', where_params = {})
    q = params[:q].to_s.strip
    exclude_id = params[:user_id].to_i
    scope = User.active.where(type: 'User')
    scope = scope.where.not(id: exclude_id) if exclude_id > 0
    scope = scope.where(where_filter, where_params) if where_filter.present?
    scope = scope.like(q) if q.present?
    scope = scope.order(last_login_on: :desc)
                 .limit(params[:limit] || Additionals::SELECT2_INIT_ENTRIES)
    @users = scope.to_a.sort! { |x, y| x.name <=> y.name }
    render layout: false, partial: 'users'
  end

  def additionals_query_to_xlsx(items, query, options = {})
    require 'write_xlsx'
    columns = if options[:columns].present? || options[:c].present?
                query.available_inline_columns
              else
                query.inline_columns
              end

    stream = StringIO.new('')
    export_to_xlsx(items, columns, filename: stream)
    stream.string
  end

  def additionals_result_to_xlsx(items, columns, options = {})
    raise 'option filename is mission' if options[:filename].blank?
    require 'write_xlsx'
    export_to_xlsx(items, columns, options)
  end

  def export_to_xlsx(items, columns, options)
    workbook = WriteXLSX.new(options[:filename])
    worksheet = workbook.add_worksheet

    # Freeze header row and # column.
    freeze_row = options[:freeze_first_row].nil? || options[:freeze_first_row] ? 1 : 0
    freeze_column = options[:freeze_first_column].nil? || options[:freeze_first_column] ? 1 : 0
    worksheet.freeze_panes(freeze_row, freeze_column)

    options[:columns_width] = if options[:xlsx_write_header_row].present?
                                send(options[:xlsx_write_header_row], workbook, worksheet, columns)
                              else
                                xlsx_write_header_row(workbook, worksheet, columns)
                              end
    options[:columns_width] = if options[:xlsx_write_item_rows].present?
                                send(options[:xlsx_write_item_rows], workbook, worksheet, columns, items, options)
                              else
                                xlsx_write_item_rows(workbook, worksheet, columns, items, options)
                              end
    columns.size.times do |index|
      worksheet.set_column(index, index, options[:columns_width][index])
    end

    workbook.close
  end

  def xlsx_write_header_row(workbook, worksheet, columns)
    columns_width = []
    columns.each_with_index do |c, index|
      value = if c.class.name == 'String'
                c
              else
                c.caption.to_s
              end

      worksheet.write(0, index, value, workbook.add_format(xlsx_cell_format(:header)))
      columns_width << xlsx_get_column_width(value)
    end
    columns_width
  end

  def xlsx_write_item_rows(workbook, worksheet, columns, items, options = {})
    hyperlink_format = workbook.add_format(xlsx_cell_format(:link))
    items.each_with_index do |line, line_index|
      columns.each_with_index do |c, column_index|
        value = csv_content(c, line)
        if c.name == :id # ID
          link = url_for(controller: line.class.name.underscore.pluralize, action: 'show', id: line.id)
          worksheet.write(line_index + 1, column_index, link, hyperlink_format, value)
        elsif xlsx_hyperlink_cell?(value)
          worksheet.write(line_index + 1, column_index, value, hyperlink_format, value)
        else
          worksheet.write(line_index + 1,
                          column_index,
                          value,
                          workbook.add_format(xlsx_cell_format(:cell, value, line_index)))
        end

        width = xlsx_get_column_width(value)
        options[:columns_width][column_index] = width if options[:columns_width][column_index] < width
      end
    end
    options[:columns_width]
  end

  def xlsx_get_column_width(value)
    value_str = value.to_s

    # 1.1: margin
    width = (value_str.length + value_str.chars.reject(&:ascii_only?).length) * 1.1
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
      format[:color] = 'red' if value.is_a?(Numeric) && value < 0
    end

    format
  end

  def xlsx_hyperlink_cell?(token)
    # Match http, https or ftp URL
    if token =~ %r{\A[fh]tt?ps?://}
      true
      # Match mailto:
    elsif token.present? && token.start_with?('mailto:')
      true
      # Match internal or external sheet link
    elsif token =~ /\A(?:in|ex)ternal:/
      true
    end
  end
end
