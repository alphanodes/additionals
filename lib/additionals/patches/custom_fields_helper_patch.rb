# frozen_string_literal: true

module Additionals
  module Patches
    # TODO(Redmine 7.0 EOL): drop, Redmine 7.1 renders the wiki toolbar of a
    # custom field itself (https://www.redmine.org/issues/43259)
    module CustomFieldsHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods unless method_defined? :with_custom_field_wiki_toolbar
      end

      module InstanceOverwriteMethods
        # The options of Redmine 7.1 for the wiki toolbar: :wiki_toolbar and :preview_url
        def custom_field_tag_with_label(name, custom_value, options = {})
          tag = super(name, custom_value, options.except(:wiki_toolbar, :preview_url))
          return tag unless options[:wiki_toolbar] && custom_value.custom_field.full_text_formatting?

          tag + wikitoolbar_for(custom_field_tag_id(name, custom_value.custom_field),
                                options[:preview_url] || preview_text_path).to_s
        end
      end
    end
  end
end
