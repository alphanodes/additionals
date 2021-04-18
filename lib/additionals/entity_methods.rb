# frozen_string_literal: true

module Additionals
  module EntityMethods
    def assignable_users(prj = nil)
      prj = project if project.present?
      users = prj.assignable_users_and_groups.to_a
      users << author if author&.active?
      if assigned_to_id_was.present?
        assignee = Principal.find_by id: assigned_to_id_was
        users << assignee if assignee
      end

      users.uniq!
      users.sort
    end
  end
end
