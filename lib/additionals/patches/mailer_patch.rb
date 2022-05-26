# frozen_string_literal: true

module Additionals
  module Patches
    module MailerPatch
      extend ActiveSupport::Concern

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
    end
  end
end
