module Additionals
  module Patches
    module FormatterTextilePatch
      def self.included(base)
        base.class_eval do
          base.send(:include, Additionals::Formatter)
          # Add :inline_emojify to list of textile functions
          if Additionals.settings[:legacy_smiley_support].to_i == 1
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
          end
        end
      end
    end
  end
end

unless Redmine::WikiFormatting::Textile::Formatter.included_modules.include? Additionals::Patches::FormatterTextilePatch
  Redmine::WikiFormatting::Textile::Formatter.send(:include, Additionals::Patches::FormatterTextilePatch)
end
