module Additionals
  module Patches
    module FormatterTextilePatch
      def self.included(base)
        base.include Additionals::Formatter

        # emojify are always enabled
        Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
      end
    end
  end
end
