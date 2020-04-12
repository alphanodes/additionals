module Additionals
  module Patches
    module ApplicationControllerPatch
      def self.included(base)
        base.include InstanceMethods
        base.class_eval do
          before_action :enable_smileys
        end
      end

      module InstanceMethods
        def enable_smileys
          return if Redmine::WikiFormatting::Textile::Formatter::RULES.include?(:inline_smileys) ||
                    !Additionals.setting?(:legacy_smiley_support)

          Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
        end
      end
    end
  end
end
