# frozen_string_literal: true

class AdditionalsRouter
  include Rails.application.routes.url_helpers

  def self.default_url_options
    ::Mailer.default_url_options
  end
end
