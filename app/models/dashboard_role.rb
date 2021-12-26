# frozen_string_literal: true

class DashboardRole < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :dashboard
  belongs_to :role

  validates :dashboard, :role,
            presence: true
end
