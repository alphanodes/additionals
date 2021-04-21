# frozen_string_literal: true

class QueryRelationsColumn < QueryColumn
  # NOTE: used for CSV and PDF export
  def value_object(object)
    (object.send name).map(&:name).join "#{Query.additional_csv_separator} "
  end
end
