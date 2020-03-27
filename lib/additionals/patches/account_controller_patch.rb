require_dependency 'account_controller'

class AccountController
  invisible_captcha(only: [:register],
                    on_timestamp_spam: :timestamp_spam_check,
                    if: -> { Additionals.setting?(:invisible_captcha) })

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
