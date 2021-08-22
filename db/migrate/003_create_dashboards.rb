# frozen_string_literal: true

class CreateDashboards < ActiveRecord::Migration[5.2]
  def change
    create_table :dashboards do |t|
      t.string :name, null: false, index: true
      t.text :description
      t.string :dashboard_type, limit: 30, default: '', null: false
      t.boolean :system_default, default: false, null: false
      t.boolean :always_expose, default: false, null: false
      t.boolean :enable_sidebar, default: false, null: false
      t.references :project,
                   type: :integer,
                   index: true,
                   foreign_key: { on_delete: :cascade }
      t.references :author,
                   type: :integer,
                   null: false,
                   index: true,
                   foreign_key: { on_delete: :cascade, to_table: :users }
      t.integer :visibility,
                index: true,
                default: Dashboard::VISIBILITY_PRIVATE,
                null: false
      t.text :options
      t.timestamps null: false
    end
  end
end
