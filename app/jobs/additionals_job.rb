# frozen_string_literal: true

if Additionals.redmine6?
  class AdditionalsJob < ApplicationJob
  end
else
  class AdditionalsJob < ActiveJob::Base
    # Automatically retry jobs that encountered a deadlock
    # retry_on ActiveRecord::Deadlocked

    # Most jobs are safe to ignore if the underlying records are no longer available
    # discard_on ActiveJob::DeserializationError

    include Additionals::JobWrapper
    around_enqueue :keep_current_user
  end
end
