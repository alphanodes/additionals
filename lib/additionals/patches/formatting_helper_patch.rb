module Additionals
  module Patches
    module FormattingHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :heads_for_wiki_formatter_without_additionals, :heads_for_wiki_formatter
          alias_method :heads_for_wiki_formatter, :heads_for_wiki_formatter_with_additionals
        end
      end

      module InstanceMethods
        def heads_for_wiki_formatter_with_additionals
          heads_for_wiki_formatter_without_additionals

          return if @additionals_macro_list

          @additionals_macro_list = AdditionalsMacro.all(project: @project, only_names: true)

          content_for :header_tags do
            render(partial: 'additionals_macros/button')
          end
        end
      end
    end
  end
end
