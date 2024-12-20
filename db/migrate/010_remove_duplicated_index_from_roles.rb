# frozen_string_literal: true

class RemoveDuplicatedIndexFromRoles < ActiveRecord::Migration[7.2]
  def change
    remove_index :dashboard_roles, name: 'index_dashboard_roles_on_dashboard_id', column: :dashboard_id
  end
end
