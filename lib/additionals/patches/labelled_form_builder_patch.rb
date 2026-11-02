# frozen_string_literal: true

module Additionals
  module Patches
    module LabelledFormBuilderPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
        # TODO(Redmine 7.0 EOL): drop WikiToolbarMethods, Redmine 7.1 brings
        # wiki_textarea (https://www.redmine.org/issues/43259)
        include WikiToolbarMethods unless method_defined? :wiki_textarea
      end

      module WikiToolbarMethods
        # Same as Redmine 7.1: a textarea with the wiki toolbar
        def wiki_textarea(field, options = {})
          options = options.dup
          preview_url = options.delete(:preview_url) || @template.preview_text_path
          options = @template.wiki_textarea_options options
          field_id = options[:id] || "#{@object_name}_#{field}"
          @template.wiki_toolbar field_id, preview_url: do
            textarea field, options
          end
        end
      end

      module InstanceOverwriteMethods
        # add info support
        # NOTE: if info = true, label symbol + _info is used, e.g. for field_author this is field_author_info
        def label_for_field(field, options = {})
          if (info = options.delete :info) && info
            text = options[:label].is_a?(Symbol) ? l(options[:label]) : options[:label]
            text ||= @object.class.human_attribute_name field

            title = if info.is_a?(TrueClass) && options[:label].is_a?(Symbol)
                      l "#{options[:label]}_info"
                    elsif info.is_a?(TrueClass) && options[:label].blank?
                      l "#{field}_info"
                    else
                      info.is_a?(Symbol) ? l(info) : info
                    end

            options[:label] = @template.tag.span text, title:, class: 'field-description'
          end

          super
        end
      end
    end
  end
end
