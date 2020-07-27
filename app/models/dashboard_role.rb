class DashboardRole < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :dashboard
  belongs_to :role
end
