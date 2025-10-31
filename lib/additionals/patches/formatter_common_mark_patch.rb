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

          if Redmine::VERSION::BRANCH == 'devel'
            # Redmine Master (7.0+) - Use Loofah Scrubbers
            to_html_with_scrubbers
          else
            # Redmine 6.1 stable - Use HTML::Pipeline Filters
            to_html_with_pipeline
          end
        end

        private

        def to_html_with_pipeline
          filters = Redmine::WikiFormatting::CommonMark::MarkdownPipeline.filters.dup
          filters << Additionals::WikiFormatting::CommonMark::SmileyFilter if Additionals.setting? :legacy_smiley_support
          filters << Additionals::WikiFormatting::CommonMark::EmojiFilter if Additionals.setting? :emoji_support
          pipeline = HTML::Pipeline.new filters, Redmine::WikiFormatting::CommonMark::PIPELINE_CONFIG

          result = pipeline.call @text
          result[:output].to_s
        end

        def to_html_with_scrubbers
          # Convert markdown to HTML
          html = Redmine::WikiFormatting::CommonMark::MarkdownFilter.new(
            @text,
            Redmine::WikiFormatting::CommonMark::PIPELINE_CONFIG
          ).call
          fragment = Redmine::WikiFormatting::HtmlParser.parse html

          # Apply sanitization
          Redmine::WikiFormatting::CommonMark::SANITIZER.call fragment

          # Apply standard Redmine scrubbers
          Redmine::WikiFormatting::CommonMark::SCRUBBERS.each do |scrubber|
            fragment.scrub! scrubber
          end

          # Apply Additionals scrubbers
          fragment.scrub! Additionals::WikiFormatting::CommonMark::SmileyScrubber.new if Additionals.setting? :legacy_smiley_support
          fragment.scrub! Additionals::WikiFormatting::CommonMark::EmojiScrubber.new if Additionals.setting? :emoji_support

          fragment.to_s
        end
      end
    end
  end
end
