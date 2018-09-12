module Additionals
  module Patches
    module AccountControllerPatch
      def self.included(base)
        base.class_eval do
          invisible_captcha only: [:register] if Additionals.setting?(:invisible_captcha)
        end
      end
    end
  end
end
