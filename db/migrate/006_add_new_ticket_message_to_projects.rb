# frozen_string_literal: true

class AddNewTicketMessageToProjects < ActiveRecord::Migration[5.2]
  def change
    change_table :projects, bulk: true do |t|
      t.text :new_ticket_message
      t.integer :enable_new_ticket_message, default: 1, null: false
    end
  end
end
