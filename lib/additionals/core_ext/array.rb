# frozen_string_literal: true

class Array
  # alias for join with ', ' as seperator
  def to_comma_list
    join ', '
  end
end
