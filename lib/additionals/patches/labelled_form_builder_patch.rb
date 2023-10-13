# frozen_string_literal: true

module Additionals
  module Patches
    module LabelledFormBuilderPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
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

            options[:label] = @template.tag.span text, title: title, class: 'field-description'
          end

          super
        end
      end
    end
  end
end
