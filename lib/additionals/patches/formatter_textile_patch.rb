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
          Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys if Additionals.setting?(:legacy_smiley_support)
          super
        end
      end
    end
  end
end
