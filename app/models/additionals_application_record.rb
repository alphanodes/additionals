# frozen_string_literal: true

# NOTE: this file is used for compatibility with Redmine 5.x and Redmine 6

class AdditionalsApplicationRecord < (defined?(ApplicationRecord) == 'constant' ? ApplicationRecord : ActiveRecord::Base)
  self.abstract_class = true
end
