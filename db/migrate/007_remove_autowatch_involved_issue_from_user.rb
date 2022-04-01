# frozen_string_literal: true

class RemoveAutowatchInvolvedIssueFromUser < ActiveRecord::Migration[5.2]
  def change
    remove_column :user_preferences, :autowatch_involved_issue, :boolean, default: false, null: false
  end
end
