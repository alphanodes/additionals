# frozen_string_literal: true

module Additionals
  module Patches
    module FormatterCommonMarkPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def to_html(*_args)
          return super unless Additionals.setting?(:legacy_smiley_support) || Additionals.setting?(:emoji_support)

          to_html_with_scrubbers
        end

        private

        def to_html_with_scrubbers
          # Convert markdown to HTML
          html = Redmine::WikiFormatting::CommonMark::MarkdownFilter.new(
            @text,
            Redmine::WikiFormatting::CommonMark::PIPELINE_CONFIG
          ).call
          fragment = Redmine::WikiFormatting::HtmlParser.parse html

          # Apply sanitization
          Redmine::WikiFormatting::CommonMark::SANITIZER.call fragment

          # Apply standard Redmine scrubbers + post processor scrubbers (inline attachments, hires images)
          scrubber = Loofah::Scrubber.new do |node|
            (Redmine::WikiFormatting::CommonMark::SCRUBBERS + post_processor_scrubbers).each do |s|
              result = s.scrub node
              break result if result == Loofah::Scrubber::STOP
              break if node.parent.nil?
            end
          end
          fragment.scrub! scrubber

          # Apply Additionals scrubbers
          fragment.scrub! Additionals::WikiFormatting::CommonMark::SmileyScrubber.new if Additionals.setting? :legacy_smiley_support
          fragment.scrub! Additionals::WikiFormatting::CommonMark::EmojiScrubber.new if Additionals.setting? :emoji_support

          fragment.to_s
        end
      end
    end
  end
end
