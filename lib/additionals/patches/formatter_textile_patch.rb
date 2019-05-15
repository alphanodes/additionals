module Additionals
  module Patches
    module FormatterTextilePatch
      def self.included(base)
        base.class_eval do
          base.send(:include, Additionals::Formatter)
          # Add :inline_emojify to list of textile functions
          if Additionals.setting?(:legacy_smiley_support)
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
          end
        end
      end
    end
  end
end
