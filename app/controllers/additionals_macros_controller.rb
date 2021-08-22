# frozen_string_literal: true

class AdditionalsMacrosController < ApplicationController
  before_action :require_login

  def show
    @available_macros = AdditionalsMacro.all
  end
end
