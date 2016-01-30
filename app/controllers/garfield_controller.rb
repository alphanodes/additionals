# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2015  AlphaNodes GmbH

# Garfield controller class
class GarfieldController < ApplicationController
  before_action :require_login

  def show
    filename = sanitize(params[:name])
    local_path = "#{Rails.root}/tmp/_garfield_#{filename}.jpg"
    send_file(local_path, disposition: 'inline', type: 'image/jpeg', x_sendfile: true)
  end
end
