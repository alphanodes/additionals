# frozen_string_literal: true

require 'csv'

# Shared base controller for plugin import controllers built on
# AdditionalsImport (e.g. DbEntryImport, PasswordImport, ContactImport).
#
# Subclasses must implement:
# - import_class: the AdditionalsImport subclass
# - new_import_path / settings_import_path / mapping_import_path /
#   run_import_path / show_import_path: redirect targets
class AdditionalsImportsController < ApplicationController
  helper :imports
  helper :queries

  before_action :find_project_by_project_id, :authorize
  before_action :find_import, only: %i[show settings mapping run]

  def show; end

  def new
    @import = import_class.new project: @project
  end

  def create
    @import = import_class.new project: @project, user: User.current
    @import.file = params[:file]
    @import.set_default_settings

    if @import.save
      redirect_to settings_import_path
    else
      render :new
    end
  end

  def settings
    redirect_to mapping_import_path if request.post? && @import.parse_file
  rescue CSV::MalformedCSVError, EncodingError => e
    flash.now[:error] = if e.is_a?(CSV::MalformedCSVError) && e.message.exclude?('Invalid byte sequence')
                          l :error_invalid_csv_file_or_settings, e.message
                        else
                          l :error_invalid_file_encoding, encoding: ERB::Util.h(@import.settings['encoding'])
                        end
  rescue SystemCallError
    flash.now[:error] = l :error_can_not_read_import_file
  end

  def mapping
    @custom_fields = @import.mappable_custom_fields

    if request.post?
      respond_to do |format|
        format.html do
          if params[:previous]
            redirect_to settings_import_path
          else
            redirect_to run_import_path
          end
        end
        format.js
      end
    else
      auto_map_fields
    end
  end

  def run
    return unless request.post?

    @current = @import.run(
      max_items: max_items_per_request,
      max_time: 10.seconds
    )
    respond_to do |format|
      format.html do
        if @import.finished?
          redirect_to show_import_path
        else
          redirect_to run_import_path
        end
      end
      format.js
    end
  end

  private

  def import_class
    raise 'overwrite it'
  end

  def new_import_path
    raise 'overwrite it'
  end

  def settings_import_path
    raise 'overwrite it'
  end

  def mapping_import_path
    raise 'overwrite it'
  end

  def run_import_path
    raise 'overwrite it'
  end

  def show_import_path
    raise 'overwrite it'
  end

  def find_import
    @import = Import.find_by user_id: User.current.id, filename: params[:id]
    @import.project = @project
    return render_404 if @import.nil?
    return redirect_to new_import_path if @import.finished? && action_name != 'show'

    update_from_params if request.post?
  end

  def update_from_params
    return if params[:import_settings].blank?

    @import.settings ||= {}
    @import.settings.merge! params[:import_settings].to_unsafe_hash
    @import.save!
  end

  def max_items_per_request
    5
  end

  def auto_map_fields
    return if @import.settings['encoding'].blank?

    mappings = @import.settings['mapping'] ||= {}
    headers = @import.headers.map { |header| header&.downcase }

    @import.class::AUTO_MAPPABLE_FIELDS.each do |field_nm, label_nm|
      next if mappings.include? field_nm

      index = headers.index(field_nm) || headers.index(l(label_nm).downcase)
      mappings[field_nm] = index if index
    end

    @custom_fields.each do |field|
      field_nm = "cf_#{field.id}"
      next if mappings.include? field_nm

      index = headers.index(field_nm) || headers.index(field.name.downcase)
      mappings[field_nm] = index if index
    end

    mappings
  end
end
