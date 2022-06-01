# frozen_string_literal: true

module Additionals
  module Patches
    module MailerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
      end

      class_methods do
        def deliver_entity_added(entity)
          deliver_method = "#{entity.class.to_s.underscore}_added"
          users = entity.notified_users | entity.notified_watchers
          users.each do |user|
            send(deliver_method, user, entity).deliver_later
          end
        end

        def deliver_entity_updated(journal)
          entity = journal.journalized
          deliver_method = "#{entity.class.to_s.underscore}_updated"

          users = entity.notified_users | entity.notified_watchers
          users.select! do |user|
            journal.notes? || journal.visible_details(user).any?
          end

          users.each do |user|
            send(deliver_method, user, journal).deliver_later
          end
        end
      end

      module InstanceMethods
        def entity_added(user, entity, entity_url:, headers:, subject:)
          redmine_headers headers
          message_id entity

          @author = entity.author
          @user = user
          @entity = entity
          @entity_url = entity_url

          mail to: user, subject: subject
        end

        def entity_updated(user, journal, entity_url:, headers:, subject:)
          entity = journal.journalized

          redmine_headers headers
          message_id journal

          @author = journal.user
          @user = user
          @entity = entity
          @entity_url = entity_url

          @journal = journal
          @journal_details = journal.visible_details

          mail to: user, subject: subject
        end
      end
    end
  end
end
