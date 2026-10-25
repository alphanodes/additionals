# frozen_string_literal: true

# A number computed by SQL, e.g. the days between two dates: lists sort by
# it, charts of queries group it in classes like a stored number. NULL is no
# value. The query brings a filter of the same name (type :integer or
# :float) for the links of the classes.
class QueryNumberColumn < QueryColumn
  attr_reader :sql, :classes

  # diverging: classes below 0 and above 0 mean opposites, e.g. early and late
  # classes: bounds of a chart without bounds of its own, a division that
  #   belongs to the number (e.g. a week early or late) instead of automatic
  #   ones over the values
  def initialize(name, sql:, diverging: false, classes: nil, **)
    super(name, sortable: sql, **)
    @sql = sql
    @diverging = diverging
    @classes = classes
  end

  def diverging?
    @diverging
  end
end
