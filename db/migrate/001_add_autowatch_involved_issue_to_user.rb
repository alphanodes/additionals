class AddAutowatchInvolvedIssueToUser < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    add_column :user_preferences, :autowatch_involved_issue, :boolean, default: true, null: false
  end
end
