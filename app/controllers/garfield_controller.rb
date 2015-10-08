
class GarfieldController < ApplicationController

  before_filter :require_login

  def show
    local_path = "#{Rails.root}/tmp/_garfield_#{params[:name]}.#{params[:type]}"
    mime_type = params[:filename] =='jpg' ? 'image/jpeg' : 'image/gif'

    send_file(local_path, :disposition => 'inline', :type => mime_type, :x_sendfile => true )
  end

end