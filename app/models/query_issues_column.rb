# frozen_string_literal: true

class QueryIssuesColumn < QueryColumn
  def initialize(name = :issue_relation, **options)
    options[:caption] ||= :field_issue_relation_plural
    super
  end

  def css_classes
    'issues'
  end
end
