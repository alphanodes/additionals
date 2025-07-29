# frozen_string_literal: true

class AdditionalsChangeStatusController < ApplicationController
  before_action :find_issue
  helper :additionals_issues

  def update
    issue_old_status_id = @issue.status.id
    issue_old_user = @issue.assigned_to
    new_status_id = params[:new_status_id].to_i
    allowed_status = @issue.sidebar_change_status_allowed_to User.current, new_status_id

    if new_status_id < 1 || @issue.status_id == new_status_id || allowed_status.nil?
      redirect_to(issue_path(@issue))
      return
    end

    @issue.init_journal User.current
    @issue.status_id = new_status_id
    @issue.assigned_to = User.current if @issue.status_x_affected?(new_status_id) && issue_old_user != User.current

    call_hook :controller_additionals_change_status_before_save,
              params:,
              issue: @issue,
              journal: @issue.current_journal

    if !@issue.save || issue_old_status_id == @issue.status_id
      flash[:error] = if issue_old_status_id == @issue.status_id
                        flash_msg :error_issue_status_could_not_changed
                      else
                        flash_msg :save_error, obj: @issue
                      end

      return redirect_to(issue_path(@issue))
    end

    call_hook :controller_additionals_change_status_after_save,
              params:,
              issue: @issue,
              journal: @issue.current_journal

    last_journal = @issue.journals.visible.order(:created_on).last

    return redirect_to(issue_path(@issue)) unless last_journal

    last_journal = @issue.journals.visible.order(:created_on).last
    redirect_to "#{issue_path @issue}#change-#{last_journal.id}"
  end

  private

  def find_issue
    @issue = Issue.find params[:issue_id]
    raise Unauthorized unless @issue.visible? && @issue.editable?

    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
