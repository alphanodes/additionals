# frozen_string_literal: true

class AddHideToRoles < ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :hide, :boolean, default: false, null: false
  end
end
