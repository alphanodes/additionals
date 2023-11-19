# frozen_string_literal: true

module Additionals
  # Usage for all entities (including redmine entities like issue)
  module EntityMethodsGlobal
    extend ActiveSupport::Concern

    included do
      include InstanceMethods
    end

    class_methods do
      # Preloads visible last notes for a collection of entity
      # this is a copy of Issue.load_visible_last_notes, but usable for all entities
      # @see https://www.redmine.org/projects/redmine/repository/entry/trunk/app/models/issue.rb#L1214
      def load_visible_last_notes(entries, user = User.current, scope = nil)
        return if entries.none?

        ids = entries.map(&:id)

        journal_class = self == Issue ? Journal : "#{self}Journal".constantize
        scope ||= journal_class.joins name.underscore.to_sym => :project
        journal_ids = scope.where(journalized_type: to_s, journalized_id: ids)
                           .where(journal_class.visible_notes_condition(user, skip_pre_condition: true))
                           .where.not(notes: '')
                           .group(:journalized_id)
                           .maximum(:id)
                           .values

        journals = Journal.where(id: journal_ids).to_a

        entries.each do |entry|
          journal = journals.detect { |j| j.journalized_id == entry.id }
          entry.instance_variable_set(:@last_notes, journal.try(:notes) || '')
        end
      end

      def load_visible_notes_count(entries, user = User.current, scope = nil)
        return if entries.none?

        ids = entries.map(&:id)
        journal_class = self == Issue ? Journal : "#{self}Journal".constantize

        scope ||= journal_class.joins name.underscore.to_sym => :project
        journals = scope.where(journalized_type: to_s, journalized_id: ids)
                        .where(journal_class.visible_notes_condition(user, skip_pre_condition: true))
                        .where.not(notes: '')
                        .group(:journalized_id)
                        .count

        entries.each do |entry|
          cnt = journals.detect { |j| j.first == entry.id }&.second
          entry.instance_variable_set(:@notes_count, cnt.nil? ? 0 : cnt)
        end
      end

      def join_enabled_module(module_name: self::ENTITY_MODULE_NAME)
        raise 'Missing module' if module_name.nil?

        "JOIN #{::EnabledModule.table_name} ON #{::EnabledModule.table_name}.project_id=#{table_name}.project_id" \
          " AND #{::EnabledModule.table_name}.name='#{module_name}'"
      end

      def like_pattern(value, wildcard = nil)
        cleaned_value = sanitize_sql_like value.to_s.strip
        return cleaned_value if wildcard.nil? || wildcard == :none

        case wildcard
        when :both
          "%#{cleaned_value}%"
        when :left
          "%#{cleaned_value}"
        when :right
          "#{cleaned_value}%"
        else
          raise 'unsupported wildcard rule'
        end
      end

      def like_with_wildcard(columns:, value:, wildcard: :none)
        sql = []
        Array(columns).each do |column|
          col = if column.to_s.include? '.'
                  col_t, col_c = column.split '.'
                  "#{connection.quote_table_name col_t}.#{connection.quote_column_name col_c}"
                else
                  connection.quote_column_name column
                end
          sql << "LOWER(#{col}) LIKE LOWER(:p) ESCAPE :s"
        end

        sql_string = sql.join ' OR '
        where sql_string, p: like_pattern(value, wildcard), s: '\\'
      end
    end

    module InstanceMethods
      def assigned_to_notified_users
        return [] unless assigned_to

        assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to]
      end

      def notes_count
        @notes_count ||= journals.where.not(notes: '').count
      end

      def tags_to_journal(old_tags, new_tags)
        return if current_journal.blank? || old_tags == new_tags

        current_journal.details << JournalDetail.new(property: 'attr',
                                                     prop_key: 'tag_list',
                                                     old_value: old_tags,
                                                     value: new_tags)
      end

      def add_remove_unused_tags_job
        AdditionalTagsRemoveUnusedTagJob.perform_later
      end
    end
  end
end
