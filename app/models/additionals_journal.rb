# frozen_string_literal: true

class AdditionalsJournal
  class << self
    def save_journal_history(journal, prop_key, ids_old, ids)
      ids_all = (ids_old + ids).uniq

      ids_all.each do |id|
        next if ids_old.include?(id) && ids.include?(id)

        if ids.include? id
          value = id
          old_value = nil
        else
          old_value = id
          value = nil
        end

        journal.details << JournalDetail.new(property: 'attr',
                                             prop_key: prop_key,
                                             old_value: old_value,
                                             value: value)
        journal.save
      end

      true
    end

    def validate_relation(entries, entry_id)
      old_entries = entries.select { |entry| entry.id.present? }
      new_entries = entries.select { |entry| entry.id.blank? }
      return true if new_entries.blank?

      new_entries.map! { |entry| entry.send entry_id }
      return false if new_entries.count != new_entries.uniq.count

      old_entries.map! { |entry| entry.send entry_id }
      return false unless (old_entries & new_entries).count.zero?

      true
    end

    # Preloads visible last notes for a collection of entity
    # this is a copy of Issue.load_visible_last_notes, but usable for all entities
    # @see https://www.redmine.org/projects/redmine/repository/entry/trunk/app/models/issue.rb#L1214
    def load_visible_last_notes(entries, entity, user = User.current)
      return unless entries.any?

      ids = entries.map(&:id)

      journal_class = (entity == Issue ? Journal : "#{entity}Journal").constantize
      journal_ids = journal_class.joins(entity.name.underscore.to_sym => :project)
                                 .where(journalized_type: entity.to_s, journalized_id: ids)
                                 .where(journal_class.visible_notes_condition(user, skip_pre_condition: true))
                                 .where.not(notes: '')
                                 .group(:journalized_id)
                                 .maximum(:id)
                                 .values

      journals = Journal.where(id: journal_ids).to_a

      entries.each do |entry|
        journal = journals.detect { |j| j.journalized_id == entry.id }
        entry.instance_variable_set('@last_notes', journal.try(:notes) || '')
      end
    end

    def set_relation_detail(entity, detail, value_key)
      value = detail.send value_key
      detail[value_key] = (entity.find_by(id: value) || value) if value.present?
    end
  end
end
