# frozen_string_literal: true

class QueryIssuesColumn < QueryColumn
  def initialize
    super(:issues, caption: :field_issue_relation_plural)
  end

  # NOTE: used for CSV and PDF export
  def value_object(object)
    (object.send name).ids.join "#{Query.additional_csv_separator} "
  end

  def css_classes
    "entity-relation #{super}"
  end
end
