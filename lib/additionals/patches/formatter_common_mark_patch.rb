# frozen_string_literal: true

module Additionals
  module Patches
    module FormatterCommonMarkPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        # Smileys and emojis are applied on top of core's finished html rather
        # than by restating its pipeline (parser, sanitizer, scrubber order).
        #
        # They cannot join core's scrubber run either: each replaces its text
        # node, so within one pass the second one would no longer find the node
        # the first has swapped out - ":) and :smile:" would lose the emoji.
        # Hence the separate passes, in that order.
        def to_html(*_args)
          html = super
          return html unless Additionals.setting?(:legacy_smiley_support) || Additionals.setting?(:emoji_support)

          fragment = Redmine::WikiFormatting::HtmlParser.parse html
          fragment.scrub! Additionals::WikiFormatting::CommonMark::SmileyScrubber.new if Additionals.setting? :legacy_smiley_support
          fragment.scrub! Additionals::WikiFormatting::CommonMark::EmojiScrubber.new if Additionals.setting? :emoji_support

          fragment.to_s
        end
      end
    end
  end
end
