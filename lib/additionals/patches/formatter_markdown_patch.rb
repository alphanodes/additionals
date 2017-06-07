module Additionals
  module Patches
    module FormatterMarkdownPatch
      def self.included(base)
        base.class_eval do
          base.send(:include, Additionals::Formatter)

          # Add a postprocess hook to redcarpet's html formatter
          def postprocess(text)
            if Additionals.settings[:legacy_smiley_support].to_i == 1
              inline_emojify(text)
            else
              text
            end
          end
        end
      end
    end
  end
end

unless Redmine::WikiFormatting::Markdown::HTML.included_modules.include? Additionals::Patches::FormatterMarkdownPatch
  Redmine::WikiFormatting::Markdown::HTML.send(:include, Additionals::Patches::FormatterMarkdownPatch)
end
