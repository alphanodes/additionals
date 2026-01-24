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
          rules_class = Additionals.textile_rules_class
          if Additionals.setting? :emoji_support
            rules_class::RULES << :inline_emojify unless rules_class::RULES.include? :inline_emojify
          else
            rules_class::RULES.delete :inline_emojify
          end

          @toc = []
          super(*rules_class::RULES).to_s
        end
      end
    end
  end
end
