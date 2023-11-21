# frozen_string_literal: true

module Additionals
  module JobWrapper
    def keep_current_user
      current_user = User.current
      yield
      User.current = current_user
    end
  end
end
