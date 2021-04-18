# frozen_string_literal: true

class AdditionalsChangeStatusController < ApplicationController
  before_action :find_issue
  helper :additionals_issues

  def update
    issue_old_status_id = @issue.status.id
    issue_old_user = @issue.assigned_to
    new_status_id = params[:new_status_id].to_i
    allowed_status = @issue.sidbar_change_status_allowed_to User.current, new_status_id

    if new_status_id < 1 || @issue.status_id == new_status_id || allowed_status.nil?
      redirect_to(issue_path(@issue))
      return
    end

    @issue.init_journal User.current
    @issue.status_id = new_status_id
    @issue.assigned_to = User.current if @issue.status_x_affected?(new_status_id) && issue_old_user != User.current

    if !@issue.save || issue_old_status_id == @issue.status_id
      flash[:error] = l :error_issue_status_could_not_changed
      return redirect_to(issue_path(@issue))
    end

    last_journal = @issue.journals.visible.order(:created_on).last

    return redirect_to(issue_path(@issue)) if last_journal.nil?

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
