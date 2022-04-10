# frozen_string_literal: true

module Additionals
  module Patches
    module FormatterMarkdownPatch
      extend ActiveSupport::Concern

      included do
        include Additionals::Formatter

        # Add a postprocess hook to redcarpet's html formatter
        def postprocess(text)
          inline_emojify text if Additionals.setting? :emoji_support

          if Additionals.setting? :legacy_smiley_support
            render_inline_smileys text
          else
            text
          end
        end
      end
    end
  end
end
