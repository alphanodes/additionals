# frozen_string_literal: true

class DashboardRole < Rails.version < '7.1' ? ActiveRecord::Base : ApplicationRecord
  include Redmine::SafeAttributes

  belongs_to :dashboard
  belongs_to :role

  validates :dashboard, :role,
            presence: true
end
