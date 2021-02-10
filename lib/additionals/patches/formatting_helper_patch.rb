module Additionals
  module Patches
    module FormattingHelperPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
        alias_method :heads_for_wiki_formatter_without_additionals, :heads_for_wiki_formatter
        alias_method :heads_for_wiki_formatter, :heads_for_wiki_formatter_with_additionals
      end

      module InstanceMethods
        def heads_for_wiki_formatter_with_additionals
          heads_for_wiki_formatter_without_additionals

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
