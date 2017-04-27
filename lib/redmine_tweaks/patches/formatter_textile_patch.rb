# Redmine Tweaks plugin for Redmine
# Copyright (C) 2013-2017 AlphaNodes GmbH

module RedmineTweaks
  module Patches
    module FormatterTextilePatch
      def self.included(base)
        base.class_eval do
          base.send(:include, RedmineTweaks::Formatter)
          # Add :inline_emojify to list of textile functions
          if Setting.plugin_redmine_tweaks[:legacy_smiley_support].to_i == 1
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_emojify
            Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
          end
        end
      end
    end
  end
end

unless Redmine::WikiFormatting::Textile::Formatter.included_modules.include? RedmineTweaks::Patches::FormatterTextilePatch
  Redmine::WikiFormatting::Textile::Formatter.send(:include, RedmineTweaks::Patches::FormatterTextilePatch)
end
