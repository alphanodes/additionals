class AdditionalsJournal
  def self.save_journal_history(journal, prop_key, ids_old, ids)
    ids_all = (ids_old + ids).uniq

    ids_all.each do |id|
      next if ids_old.include?(id) && ids.include?(id)

      if ids.include?(id)
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
end
