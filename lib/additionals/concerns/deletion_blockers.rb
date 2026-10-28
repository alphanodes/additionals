# frozen_string_literal: true

module Additionals
  module Concerns
    # An entry that other records refer to can only be deleted once nothing refers
    # to it any more, so a deletion never takes data of other entries along with
    # it. The model and other plugins register the references with
    # add_deletion_blocker. The check runs in the model, so it applies to the
    # user interface, the API and every other caller of destroy alike.
    module DeletionBlockers
      extend ActiveSupport::Concern

      # scope returns the referencing records, column holds the id of the entry,
      # projects reads the project ids from the references of one entry
      Blocker = Data.define :label, :scope, :column, :projects do
        def relation
          scope.call.all
        end

        # { entry id => number of referencing records }
        def counts(ids)
          relation.where(column => ids.map(&:to_s))
                  .group(column)
                  .count
                  .transform_keys(&:to_i)
        end

        # Custom values keep the id as a string, which PostgreSQL does not compare
        # with an integer column, so their ids are read first.
        def entry_ids
          if relation.klass.type_for_attribute(column).type == :integer
            relation.select column
          else
            relation.distinct.pluck(column).map(&:to_i)
          end
        end

        def project_ids(id)
          return [] unless projects

          projects.call relation.where(column => id.to_s)
        end
      end

      included do
        class_attribute :deletion_blockers, instance_writer: false, default: {}

        # Set when the owner of the entry goes and takes it along outside of an
        # association, e.g. the private entries of a deleted user
        attr_accessor :deleted_with_owner

        # prepend: before the dependent callbacks of the associations
        before_destroy :check_deletion_blockers, prepend: true
      end

      class_methods do
        def add_deletion_blocker(name, label:, scope:, column:, projects: nil)
          self.deletion_blockers = deletion_blockers.merge name => Blocker.new(label:, scope:, column:, projects:)
        end

        # Values of custom fields of the given formats, which store the id of the
        # entry as a plain string
        def custom_values_of_formats(*formats)
          CustomValue.where custom_field_id: CustomField.where(field_format: formats).select(:id)
        end

        # The projects of the records custom values belong to: a project itself or
        # anything with a project_id (issues, versions, time entries, ...). Values
        # of users and other records without a project name none.
        def projects_of_custom_values(custom_values)
          custom_values.distinct.pluck(:customized_type, :customized_id)
                       .group_by(&:first)
                       .flat_map do |type, pairs|
                         klass = type.safe_constantize
                         ids = pairs.map(&:last)
                         if klass == Project
                           ids
                         elsif klass&.column_names&.include? 'project_id'
                           klass.where(id: ids).pluck(:project_id)
                         else
                           []
                         end
                       end
        end

        # Entries something still refers to
        def with_deletion_blockers
          deletion_blockers.each_value
                           .map { |blocker| unscoped.where id: blocker.entry_ids }
                           .inject(:or) || none
        end

        # { entry id => { blocker name => count } }, one query per blocker
        def deletion_blocker_counts(ids)
          deletion_blockers.each_with_object({}) do |(name, blocker), result|
            blocker.counts(ids).each do |id, count|
              (result[id] ||= {})[name] = count
            end
          end
        end

        # Loads the blockers of a page of entries at once, as a query column needs
        # them for every row
        def load_deletion_blockers(entries)
          counts = deletion_blocker_counts entries.map(&:id)
          entries.each { |entry| entry.instance_variable_set :@deletion_blocker_counts, counts[entry.id] || {} }
        end
      end

      def deletion_blocker_counts
        @deletion_blocker_counts ||= self.class.deletion_blocker_counts([id])[id] || {}
      end

      def deletion_blocked?
        deletion_blocker_counts.any?
      end

      # "Issue relations (3), Custom fields (1)"
      def deletion_blocked_by
        deletion_blocker_counts.map { |name, count| "#{l deletion_blockers[name].label} (#{count})" }.to_comma_list
      end

      def deletion_blocked_message
        l :error_deletion_blocked, name: to_s, reasons: deletion_blocked_by
      end

      # The projects the references to this entry belong to
      def reference_project_ids
        deletion_blockers.each_value.flat_map { |blocker| blocker.project_ids id }.tap(&:uniq!)
      end

      private

      # Counted again: references may have moved right before the destroy.
      # An entry deleted along with its owner (dependent: :destroy, e.g. the
      # entries of a deleted project, or deleted_with_owner) goes with it, the
      # owner decides.
      def check_deletion_blockers
        return if destroyed_by_association || deleted_with_owner

        @deletion_blocker_counts = nil
        return unless deletion_blocked?

        errors.add :base, deletion_blocked_message
        throw :abort
      end
    end
  end
end
