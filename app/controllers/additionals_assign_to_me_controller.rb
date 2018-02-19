class AdditionalsAssignToMeController < ApplicationController
  before_action :find_issue
  helper :additionals_issues

  def update
    old_user = @issue.assigned_to
    user_in_project = @project.assignable_users.detect { |u| u.id == User.current.id }

    if old_user == User.current || user_in_project.nil?
      redirect_to(issue_path(@issue))
      return
    end

    @issue.assigned_to = User.current

    if !@issue.save || old_user == @issue.assigned_to
      flash[:error] = l(:error_issues_could_not_be_assigned_to_me)
      return redirect_to(issue_path(@issue))
    end

    new_journal = @issue.init_journal(User.current)
    new_journal.save!

    last_journal = @issue.journals.visible.order('created_on').last

    JournalDetail.new(property: 'attr',
                      prop_key: 'assigned_to',
                      old_value: old_user,
                      value: @issue.assigned_to,
                      journal: new_journal).save!

    if last_journal.nil?
      redirect_to(issue_path(@issue))
      return
    end

    last_journal = @issue.journals.visible.order('created_on').last
    redirect_to "#{issue_path(@issue)}#change-#{last_journal.id}"
  end

  private

  def find_issue
    @issue = Issue.find_by(id: params[:issue_id].to_i)
    raise Unauthorized unless @issue.visible? && @issue.editable?
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
