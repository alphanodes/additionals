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

  def query_to_xls(items, query, options = {})
    require 'spreadsheet'
    Spreadsheet.client_encoding = options[:encoding].presence || 'UTF-8'
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    columns = query.columns
    headers = columns.map { |c| c.caption.to_s }
    idx = 0
    row = sheet.row(idx)
    row.replace headers
    items.each do |item|
      idx += 1
      row = sheet.row(idx)
      fields = columns.map { |c| csv_content(c, item) }
      row.replace fields
    end

    xls_stream = StringIO.new('')
    book.write(xls_stream)

    xls_stream.string
  end
end
