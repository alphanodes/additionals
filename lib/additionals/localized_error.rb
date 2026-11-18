# frozen_string_literal: true

module Additionals
  # An error carried as the case it is instead of as a finished sentence.
  #
  # A test can then name the case without knowing the language, and the message
  # is built in the language of whoever reads it - which is not necessarily the
  # one it was raised in, a background job has no user.
  class LocalizedError < StandardError
    include Redmine::I18n

    attr_reader :key, :params

    def initialize(key, **params)
      @key = key
      @params = params
      super key.to_s
    end

    def to_s
      l key, **params
    end
  end
end
