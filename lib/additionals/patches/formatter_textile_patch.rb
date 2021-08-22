# frozen_string_literal: true

module Additionals
  module Patches
    module FormatterTextilePatch
      extend ActiveSupport::Concern

      included do
        include Additionals::Formatter

        # emojify are always enabled
        Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
      end
    end
  end
end
