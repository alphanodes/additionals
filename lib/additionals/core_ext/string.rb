# frozen_string_literal: true

class String
  def strip_split(sep = ',')
    split(sep).map(&:strip).compact_blank
  end
end
