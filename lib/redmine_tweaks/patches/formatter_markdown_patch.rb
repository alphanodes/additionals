# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  module Patches
    module FormatterMarkdownPatch
      def self.included(base)
        base.class_eval do
          base.send(:include, RedmineTweaks::Formatter)

          # Add a postprocess hook to redcarpet's html formatter
          def postprocess(text)
            if RedmineTweaks.settings[:legacy_smiley_support].to_i == 1
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

unless Redmine::WikiFormatting::Markdown::HTML.included_modules.include? RedmineTweaks::Patches::FormatterMarkdownPatch
  Redmine::WikiFormatting::Markdown::HTML.send(:include, RedmineTweaks::Patches::FormatterMarkdownPatch)
end
