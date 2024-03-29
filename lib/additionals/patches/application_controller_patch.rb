# frozen_string_literal: true

module Additionals
  module Patches
    module ApplicationControllerPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
        before_action :enable_smileys
      end

      module InstanceMethods
        def enable_smileys
          return if !Additionals.setting?(:legacy_smiley_support) ||
                    Redmine::WikiFormatting::Textile::Formatter::RULES.include?(:inline_smileys)

          Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smileys
        end
      end
    end
  end
end
