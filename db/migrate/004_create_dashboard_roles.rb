# frozen_string_literal: true

class CreateDashboardRoles < ActiveRecord::Migration[5.2]
  def change
    create_table :dashboard_roles do |t|
      t.references :dashboard,
                   null: false,
                   foreign_key: { on_delete: :cascade }
      t.references :role,
                   null: false,
                   type: :integer,
                   foreign_key: { on_delete: :cascade }
      t.index %i[dashboard_id role_id], name: 'dashboard_role_ids', unique: true
    end
  end
end
