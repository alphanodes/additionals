# frozen_string_literal: true

class AddLockedToDashboards < ActiveRecord::Migration[6.1]
  def change
    add_column :dashboards, :locked, :boolean, default: false, null: false
  end
end
