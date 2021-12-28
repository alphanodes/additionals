# frozen_string_literal: true

module Additionals
  # Usage for all entities (including redmine entities like issue)
  module EntityMethodsGlobal
    extend ActiveSupport::Concern

    included do
      include InstanceMethods
    end

    class_methods do
      def join_enabled_module(module_name: self::ENTITY_MODULE_NAME)
        raise 'Missing module' if module_name.nil?

        "JOIN #{::EnabledModule.table_name} ON #{::EnabledModule.table_name}.project_id=#{table_name}.project_id" \
          " AND #{::EnabledModule.table_name}.name='#{module_name}'"
      end
    end

    module InstanceMethods
      def tags_to_journal(old_tags, new_tags)
        return if current_journal.blank? || old_tags == new_tags

        current_journal.details << JournalDetail.new(property: 'attr',
                                                     prop_key: 'tag_list',
                                                     old_value: old_tags,
                                                     value: new_tags)
      end
    end
  end
end
