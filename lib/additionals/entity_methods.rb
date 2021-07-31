# frozen_string_literal: true

module Additionals
  module EntityMethods
    attr_reader :current_journal

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

    def last_notes
      @last_notes ||= journals.where.not(notes: '').reorder(id: :desc).first.try(:notes)
    end

    def new_status
      true if created_on == updated_on
    end

    # Returns the id of the last journal or nil
    def last_journal_id
      if new_record?
        nil
      else
        journals.maximum :id
      end
    end

    # Saves the changes in a Journal
    # Called after_save
    def create_journal
      current_journal&.save
    end
  end
end
