# frozen_string_literal: true

module Additionals
  # Only used for non default Redmine entities (not for issues, time_tracking, etc)
  module EntityMethods
    extend ActiveSupport::Concern

    included do
      include Additionals::EntityMethodsGlobal
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
        Redmine::Hook.call_hook :model_notified_users, entity: self, notified: notified

        notified = notified.select(&:active?)
        notified.uniq!

        # Remove users that can not view the entity
        notified.select! { |user| visible? user }
        notified
      end

      # used with assignable_principal (user AND groups)
      def assignable_users(prj = nil)
        prj = project if project
        users = if prj
                  prj.assignable_principals.to_a
                else
                  Principal.assignable.to_a
                end

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

      # Returns the journals that are visible to user with their index
      # Used to display the issue history
      # ! this is a replacement of Redmine method for all entities
      def visible_journals_with_index(_user = User.current, scope: nil)
        scope ||= journals
        result = scope.includes(:details)
                      .includes(user: :email_address)
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
