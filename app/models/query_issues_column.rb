# frozen_string_literal: true

class QueryIssuesColumn < QueryColumn
  def initialize
    super(:issues, caption: :field_issue_relation_plural)
  end

  def css_classes
    "entity-relation #{super}"
  end
end
