# frozen_string_literal: true

module Additionals
  module Patches
    module FormattingHelperPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def heads_for_wiki_formatter
          super
          return if @additionals_macro_list

          @additionals_macro_list = AdditionalsMacro.all(filtered: Additionals.setting(:hidden_macros_in_toolbar).to_a,
                                                         only_names: true,
                                                         controller_only: controller_name)

          return if @additionals_macro_list.count.zero?

          content_for :header_tags do
            javascript_include_tag('additionals_macro_button', plugin: 'additionals') +
              javascript_tag("jsToolBar.prototype.macroList = #{@additionals_macro_list.to_json};")
          end
        end
      end
    end
  end
end
