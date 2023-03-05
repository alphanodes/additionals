# frozen_string_literal: true

class ActivateLockedForSystemDefaultDashboards < ActiveRecord::Migration[6.1]
  def up
    Dashboard.where(system_default: true, project_id: nil)
             .update_all locked: true
  end
end
