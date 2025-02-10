# frozen_string_literal: true

class QueryRelationsColumn < QueryColumn
  # NOTE: used for CSV and PDF export
  def value_object(object)
    entries = (object.send name)
    entries = entries.visible if defined?(entries.visible)
    entries.map(&:name).join "#{Query.additional_csv_separator} "
  end

  def css_classes
    "entity-relation #{super}"
  end
end
