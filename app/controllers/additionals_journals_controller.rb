# frozen_string_literal: true

# This file is a part of redmine_db,
# a Redmine plugin to manage custom database entries.
#
# Copyright (c) 2016-2021 AlphaNodes GmbH
# https://alphanodes.com

class AdditionalsJournalsController < ApplicationController
  before_action :find_journal, only: %i[edit update diff]
  before_action :authorize, only: %i[edit update]

  helper :custom_fields
  helper :journals
  helper :additionals_journals

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

  def edit
    return render_403 unless @journal.editable_by? User.current

    respond_to do |format|
      # TODO: implement non-JS journal update
      format.js
    end
  end

  def update
    return render_403 unless @journal.editable_by? User.current

    @journal.safe_attributes = params[:journal]
    @journal.save
    @journal.destroy if @journal.details.empty? && @journal.notes.blank?
    respond_to do |format|
      format.html { redirect_after_update }
      format.js
    end
  end

  private

  def redirect_after_update
    raise 'overwrite it'
  end

  def find_journal
    raise 'overwrite it'
  end
end
