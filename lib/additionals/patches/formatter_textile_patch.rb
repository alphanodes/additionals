module Additionals
  module Patches
    module FormatterTextilePatch
      def self.included(base)
        base.send(:include, Additionals::Formatter)
        base.send(:prepend, InstancOverwriteMethods)

        Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
      end

      module InstancOverwriteMethods
        def to_html(*rules)
          if Redmine::WikiFormatting::Textile::Formatter::RULES.exclude?(:inline_smileys) &&
             Additionals.setting?(:legacy_smiley_support)
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
          end

          super
        end
      end
    end
  end
end
