class AdditionalsChangeStatusController < ApplicationController
  before_action :find_issue
  helper :additionals_issues

  def update
    issue_old_status_id = @issue.status.id
    issue_old_user = @issue.assigned_to
    new_status_id = params[:new_status_id].to_i
    allowed_status = @issue.new_statuses_allowed_to(User.current)
                           .detect { |s| s.id == new_status_id }

    if new_status_id < 1 || @issue.status_id == new_status_id || allowed_status.nil?
      redirect_to(issue_path(@issue))
      return
    end

    @issue.status_id = new_status_id
    @issue.assigned_to = User.current if @issue.status_x_affected?(new_status_id) && issue_old_user != User.current

    if !@issue.save || issue_old_status_id == @issue.status_id
      flash[:error] = l(:error_issue_status_could_not_changed)
      return redirect_to(issue_path(@issue))
    end

    new_journal = @issue.init_journal(User.current)
    new_journal.save!

    last_journal = @issue.journals.visible.order('created_on').last

    JournalDetail.new(property: 'attr',
                      prop_key: 'status_id',
                      old_value: issue_old_status_id,
                      value: @issue.status_id,
                      journal: new_journal).save!

    if @issue.assigned_to != issue_old_user
      JournalDetail.new(property: 'attr',
                        prop_key: 'assigned_to',
                        old_value: issue_old_user,
                        value: @issue.assigned_to,
                        journal: new_journal).save!
    end

    if last_journal.nil?
      redirect_to(issue_path(@issue))
      return
    end

    last_journal = @issue.journals.visible.order('created_on').last
    redirect_to "#{issue_path(@issue)}#change-#{last_journal.id}"
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    raise Unauthorized unless @issue.visible? && @issue.editable?
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
