# frozen_string_literal: true

class AdditionalsJournalsController < ApplicationController
  before_action :find_journal, only: %i[edit update diff]
  before_action :find_entry, only: %i[create]
  before_action :authorize, only: %i[create edit update]

  helper :custom_fields
  helper :journals
  helper :additionals_journals

  def edit
    return render_403 unless @journal.editable_by? User.current

    respond_to do |format|
      # TODO: implement non-JS journal update
      format.js { render 'additionals_journals/edit' }
    end
  end

  def create; end

  def update
    return render_403 unless @journal.editable_by? User.current

    journal_attributes = params[:journal]
    journal_attributes[:updated_by] = User.current
    @journal.safe_attributes = journal_attributes
    @journal.save
    @journal.destroy if @journal.details.empty? && @journal.notes.blank?
    call_hook(:controller_additionals_journals_edit_post, { journal: @journal, params: params })
    respond_to do |format|
      format.html { redirect_after_update }
      format.js { render 'additionals_journals/update' }
    end
  end

  def diff
    @entry = @journal.journalized
    @detail =
      if params[:detail_id].present?
        @journal.details.find_by id: params[:detail_id]
      else
        @journal.details.detect { |d| d.property == 'attr' && d.prop_key == 'description' }
      end
    unless @entry && @detail
      render_404
      return false
    end

    raise ::Unauthorized if @detail.property == 'cf' && !@detail.custom_field&.visible_by?(@entry.project, User.current)

    @diff = Redmine::Helpers::Diff.new @detail.value, @detail.old_value
  end

  private

  def redirect_after_update
    redirect_to @journal.journalized
  end

  def find_journal
    raise 'overwrite it'
  end
end
