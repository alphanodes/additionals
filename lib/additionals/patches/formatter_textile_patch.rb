# frozen_string_literal: true

module Additionals
  module Patches
    module FormatterTextilePatch
      extend ActiveSupport::Concern

      included do
        include Additionals::Formatter
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def to_html(*_rules)
          if Additionals.setting? :emoji_support
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
          else
            Redmine::WikiFormatting::Textile::Formatter::RULES.delete :inline_emojify
          end

          @toc = []
          super(*Redmine::WikiFormatting::Textile::Formatter::RULES).to_s
        end
      end
    end
  end
end
