# frozen_string_literal: true

module AdditionalsQueriesHelper
  def additionals_limit_for_pager
    params[:search].present? ? Additionals.max_live_search_results : per_page_option
  end

  def render_live_search_info(entries:, count: nil)
    return if count.nil? ||
              count <= Additionals.max_live_search_results ||
              entries.count < Additionals.max_live_search_results

    tag.p class: 'icon icon-warning' do
      tag.em class: 'info' do
        l :info_live_search_result_restriction, value: Additionals.max_live_search_results
      end
    end
  end

  def render_grouped_users_with_select2(users, search_term: nil, with_me: true, with_ano: false, me_value: 'me')
    @users = { active: [], groups: [], registered: [], locked: [] }

    users = users.like search_term if search_term.present?

    sorted_users = users.select("users.*, #{User.table_name}.last_login_on IS NULL AS select_order")
                        .order("select_order ASC, #{User.table_name}.last_login_on DESC")
                        .limit(AdditionalsConf.select2_init_entries)
                        .to_a
                        .sort_by(&:name)

    with_users = false
    sorted_users.each do |user|
      case user.type
      when 'User'
        case user.status
        when Principal::STATUS_ACTIVE
          @users[:active] << { id: user.id, name: user.name, obj: user }
          with_users = true
        when Principal::STATUS_REGISTERED
          @users[:registered] << { id: user.id, name: user.name, obj: user }
          with_users = true
        when Principal::STATUS_LOCKED
          @users[:locked] << { id: user.id, name: user.name, obj: user }
          with_users = true
        end
      when 'Group'
        @users[:groups] << { id: user.id, name: user.name, obj: user }
        with_users = true
      end
    end

    # TODO: this should be false without search results?
    # with_me = false unless with_users

    # Additionals.debug "with_me: #{with_me}"
    # Additionals.debug "active: #{@users[:active].pluck :id}"
    # Additionals.debug "locked: #{@users[:locked].pluck :id}"
    # Additionals.debug "groups: #{@users[:groups].pluck :id}"

    respond_to do |format|
      format.html { head :not_acceptable }
      format.js do
        render layout: false,
               format: :json,
               partial: 'auto_completes/grouped_users',
               locals: { with_me: with_me && (search_term.blank? || l(:label_me).downcase.include?(search_term.downcase)),
                         with_ano: with_ano && (search_term.blank? || l(:label_user_anonymous).downcase.include?(search_term.downcase)),
                         me_value:,
                         sep_required: false }
      end
    end
  end

  def additionals_query_to_xlsx(query, no_id_link: false)
    require 'write_xlsx'

    options = { no_id_link:,
                filename: StringIO.new(+'') }

    export_to_xlsx query.entries, query.columns, options
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
          if options[:no_id_link]
            # id without link
            worksheet.write(line_index + 1,
                            column_index,
                            value,
                            workbook.add_format(xlsx_cell_format(:cell, value, line_index)))
          else
            link = send :"#{line.class.name.underscore}_url", id: line.id
            worksheet.write line_index + 1, column_index, link, hyperlink_format, value
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
    [width, 30].min
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
    return false if token.blank? || !token.is_a?(String)

    # Match http, https or ftp URL
    %r{\A[fh]tt?ps?://}.match?(token) ||
      # Match mailto:
      token.start_with?('mailto:') ||
      # Match internal or external sheet link
      /\A(?:in|ex)ternal:/.match?(token)
  end

  def set_flash_from_bulk_save(entries, unsaved_ids, name_plural:)
    if unsaved_ids.empty?
      flash[:notice] = flash_msg :update unless entries.empty?
    else
      flash[:error] = l :notice_failed_to_save_entity,
                        name_plural:,
                        count: unsaved_ids.size,
                        total: entries.size,
                        ids: "##{unsaved_ids.join ', #'}"
    end
  end

  # Returns the query definition as hidden field tags
  # columns in ignored_column_names are skipped (names as symbols)
  # TODO: this is a temporary fix and should be removed
  # after https://www.redmine.org/issues/29830 is in Redmine core.
  def query_as_hidden_field_tags(query, with_block_columns: false)
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

    ignored_block_columns = with_block_columns ? [] : query.block_columns.map(&:name)
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

  def build_search_query_term(params)
    (params[:q] || params[:term]).to_s.strip
  end

  def link_to_nonzero(value, path)
    value.zero? ? value : link_to(value, path)
  end

  def link_to_issues(issues)
    issues = Array(issues).flatten
    safe_join(issues.map { |issue| link_to_issue(issue, subject: false, tracker: false) }, ', ')
  end

  def link_to_query_filter(url, title:)
    link_to svg_icon_tag('filter', label: :button_filter),
            url,
            title: title.is_a?(Symbol) ? l(title) : title,
            class: 'icon-only icon-list'
  end
end
