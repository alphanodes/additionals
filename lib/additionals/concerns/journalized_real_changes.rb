# frozen_string_literal: true

module Additionals
  module Concerns
    # "Did anything meaningful change?" check for journalized entities. Mixed into
    # Additionals::EntityMethods, so every entity that includes EntityMethods
    # (DbEntry, Contact, Invoice, Password, the redmine_templates entities, Budget,
    # ...) gets it; redmine_reporting also mixes it into Issue via its issue_patch,
    # since Issue (Redmine core) does not include EntityMethods.
    #
    # Only redmine_reporting consumes it - its after_update callback logs a model
    # update only when real_changes? is true. The method lives here (not in
    # reporting) because it is journal infrastructure, the sibling of
    # current_journal / init_journal / create_journal already in EntityMethods.
    # Without redmine_reporting it is simply unused (harmless): there is no hard
    # dependency on reporting, and the tag bits are defensive
    # (@prepare_save_tag_change is nil, the tag_list delete is a no-op).
    #
    # WHY IT IS PAIRED WITH force_updated_on_change: entities bump updated_on via a
    # force_updated_on_change before_save as soon as a journal is initialized - so
    # that journal-only edits (notes, relations) whose data lives outside the
    # entity's own table still count as changed. The side effect is that even a
    # truly empty save bumps updated_on/lock_version. The simple default check
    # (previous_changes.present?) would treat that as a real change and log noise;
    # this variant strips updated_on/lock_version/tag_list and only reports a real
    # column change, a journal note/detail, or a really changed custom field value.
    # So the two are a pair: force_updated_on_change keeps updated_on/sorting/feeds
    # correct, this keeps the reporting log free of empty-save noise.
    module JournalizedRealChanges
      extend ActiveSupport::Concern

      def real_changes?(with_details: true)
        if changed.present?
          changes = changed.dup
          changes.delete 'tag_list'
          changes.delete 'updated_on'
        else
          changes = saved_changes.dup
          changes.delete 'tag_list'
          changes.delete 'updated_on'
          changes.delete 'lock_version'
        end

        # NOTE: details.count (DB query), not details.any? (in-memory). An
        # unsaved current_journal can carry transient, never-persisted detail
        # objects - e.g. Redmine builds a child_id detail on the parent when a
        # child is attached, which is discarded (no real parent edit). count
        # only sees persisted details and so ignores that noise; any? would
        # treat the phantom detail as a real change and log empty saves.
        @prepare_save_tag_change ||
          changes.any? ||
          (with_details && (current_journal&.notes.present? ||
                            (current_journal&.details&.count || 0).positive? ||
                            custom_field_values_really_changed?))
      end

      def custom_field_values_really_changed?
        return false unless respond_to? :custom_field_values

        custom_field_values.detect { |c| c.respond_to?(:value_was) && c.value != c.value_was }.present?
      end
    end
  end
end
