module AdditionalsQueryHelper
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
