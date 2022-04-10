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

          filters = Redmine::WikiFormatting::CommonMark::MarkdownPipeline.filters.dup
          filters << Additionals::WikiFormatting::CommonMark::SmileyFilter if Additionals.setting? :legacy_smiley_support
          filters << Additionals::WikiFormatting::CommonMark::EmojiFilter if Additionals.setting? :emoji_support
          pipeline = HTML::Pipeline.new filters, Redmine::WikiFormatting::CommonMark::PIPELINE_CONFIG

          result = pipeline.call @text
          result[:output].to_s
        end
      end
    end
  end
end
