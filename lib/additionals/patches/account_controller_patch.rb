module Additionals
  module Patches
    module AccountControllerPatch
      def self.included(base)
        base.class_eval do
          invisible_captcha only: [:register] if Additionals.setting?(:invisible_captcha)

          helper :additionals_menu
          helper :additionals_fontawesome

          include AdditionalsMenuHelper
          include AdditionalsFontawesomeHelper
          include ActionView::Helpers::TagHelper
          include ActionView::Helpers::UrlHelper
        end
      end
    end
  end
end
