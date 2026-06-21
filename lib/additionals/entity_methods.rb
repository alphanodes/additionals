# frozen_string_literal: true

module Additionals
  # Only used for non default Redmine entities (not for issues, time_tracking, etc)
  module EntityMethods
    extend ActiveSupport::Concern

    included do
      include Additionals::EntityMethodsGlobal
      include Additionals::Concerns::JournalizedRealChanges
      include InstanceMethods

      attr_reader :current_journal
    end

    class_methods do
      # if project is available, it is always included
      def allowed_entity_target_projects(permission:, user: User.current, exclude: nil, project: nil)
        scope = Project.where Project.allowed_to_condition(user, permission)
        scope = scope.or Project.where id: project if project
        scope = scope.where.not id: exclude if exclude
        scope
      end
    end

    module InstanceMethods
      def notified_users
        notified = []
        # Author and assignee are always notified unless they have been
        # locked or don't want to be notified
        notified << author if author
        notified += assigned_to_notified_users if assigned_to
        notified += project.notified_users if project
        Redmine::Hook.call_hook(:model_notified_users, entity: self, notified:)

        notified = notified.select(&:active?)
        notified.uniq!

        # Remove users that can not view the entity
        notified.select! { |user| visible? user }
        notified
      end

      # Assignable principals for custom entities (Users AND Groups).
      #
      # IMPORTANT: This method ALWAYS includes groups, regardless of Setting.issue_group_assignment?
      # That setting is for Issues only! Custom entities like Password need group assignment
      # independently - a user may disable group assignment for issues but still want to
      # assign passwords to groups for access control.
      #
      # Uses project_assignable_principals (NOT project_assignable_users!) to ensure
      # groups are always available. See AssignableUsersOptimizer for details.
      #
      # @param prj [Project, nil] Optional project context
      # @return [Array<Principal>] Assignable users and groups
      def assignable_users(prj = nil)
        prj = project if project

        # Use optimized implementation that:
        # - ALWAYS includes Users AND Groups (not depending on issue settings!)
        # - Respects hidden roles security
        # - Prevents N+1 queries
        principals = if prj
                       Additionals::AssignableUsersOptimizer.project_assignable_principals prj
                     else
                       # For entities without project context, use global assignable principals
                       # This is a fallback and should be used carefully
                       Additionals::AssignableUsersOptimizer.global_assignable_principals
                     end

        # Add author if active (authors should always be assignable to their own entities)
        principals << author if author&.active? && principals.exclude?(author)

        # Add previous assignee if it was changed (to allow reassigning back)
        if assigned_to_id_was.present?
          assignee = Principal.find_by id: assigned_to_id_was
          principals << assignee if assignee && principals.exclude?(assignee)
        end

        principals.uniq!
        principals.sort
      end

      def last_notes
        @last_notes ||= journals.where.not(notes: '').reorder(id: :desc).first.try(:notes)
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

      # Bump updated_on for journal-only edits (notes, relations) whose data lives
      # outside the entity's own table, so the entity sorts/feeds correctly as
      # changed. Without this, a note- or relation-only edit would leave updated_on
      # untouched (only custom field changes are covered, via Redmine-core's
      # acts_as_customizable touch).
      #
      # Shared here as opt-in: register it per model with
      # `before_save :force_updated_on_change`. It is deliberately NOT registered
      # as a callback in EntityMethods, so entities that do not want it (or do not
      # journalize) are unaffected.
      #
      # We use this "dumb" variant (any initialized journal) rather than
      # Redmine-core's Issue#force_updated_on_change, which only touches when the
      # journal already has notes/details: relation details are written *after*
      # save (controller after-save hooks), so at this point the journal still
      # looks empty and the smart check would miss relation-only changes. The
      # downside - a truly empty save also bumps updated_on - is filtered out for
      # reporting by JournalizedRealChanges#real_changes? (the two are a pair).
      def force_updated_on_change
        return unless @current_journal || changed?

        self.updated_on = current_time_from_proper_timezone
      end

      # Returns the journals that are visible to user with their index
      # Used to display the issue history
      # ! this is a replacement of Redmine method for all entities
      def visible_journals_with_index(_user = User.current, scope: nil, includes: [])
        scope ||= journals
        result = scope.includes(%i[details updated_by])
                      .includes(user: :email_address)
        result = result.includes(includes) if includes.any?
        result = if User.current.wants_comments_in_reverse_order?
                   result.reorder created_on: :desc, id: :desc
                 else
                   result.reorder :created_on, :id
                 end.to_a
        result.each_with_index { |j, i| j.indice = i + 1 }
        Journal.preload_journals_details_custom_fields result
        result.select! { |journal| journal.notes? || journal.visible_details.any? }
        result
      end

      # Callback on file attachment
      def attachment_added(attachment)
        return if attachment.new_record? || new_record? || id_previously_changed?

        init_journal User.current if current_journal.nil?
        current_journal.journalize_attachment attachment, :added
        current_journal.save!
      end

      # Callback on attachment deletion
      def attachment_removed(attachment)
        init_journal User.current
        current_journal.journalize_attachment attachment, :removed
        current_journal.save!
      end
    end
  end
end
