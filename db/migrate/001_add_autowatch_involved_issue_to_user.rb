class AddAutowatchInvolvedIssueToUser < ActiveRecord::Migration
  def change
    add_column :user_preferences, :autowatch_involved_issue, :boolean, default: true, null: false
  end
end
