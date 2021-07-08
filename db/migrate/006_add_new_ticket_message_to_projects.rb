# frozen_string_literal: true

class AddNewTicketMessageToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :new_ticket_message, :text
    add_column :projects, :enable_new_ticket_message, :integer, default: 1, null: false
  end
end
