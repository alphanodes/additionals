class MacrosController < ApplicationController
  before_action :require_login

  def show
    @available_macros = Redmine::WikiFormatting::Macros.available_macros.sort
  end
end
