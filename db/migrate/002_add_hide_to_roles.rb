class AddHideToRoles < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :hide, :boolean, default: false, null: false
  end
end
