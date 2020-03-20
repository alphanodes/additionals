module Additionals
  module Patches
    module AccountControllerPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          invisible_captcha(only: [:register], on_timestamp_spam: :timestamp_spam_check) if Additionals.setting?(:invisible_captcha)
        end
      end
      module InstanceMethods
        # required because invisible_captcha uses root_path, which is not available for Redmine
        def timestamp_spam_check
          # redmine uses same action for _GET and _POST
          return unless request.post?

          if respond_to?(:redirect_back)
            redirect_back(fallback_location: home_url, flash: { error: InvisibleCaptcha.timestamp_error_message })
          else
            redirect_to :back, flash: { error: InvisibleCaptcha.timestamp_error_message }
          end
        end
      end
    end
  end
end
