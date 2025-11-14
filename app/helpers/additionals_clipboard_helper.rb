# frozen_string_literal: true

module AdditionalsClipboardHelper
  # Creates a button that copies text to clipboard using Redmine Core's native clipboard functionality
  #
  # @param text [String] The text to copy to clipboard
  # @param icon [String] Custom icon name (default: 'copy')
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text (default: l(:button_copy))
  # @return [String] HTML button element
  #
  # @example
  #   clipboard_copy_button('secret_password')
  #   clipboard_copy_button('text', icon: 'copy-link', css_class: 'custom-class')
  def clipboard_copy_button(text, icon: 'copy', css_class: nil, title: nil)
    return if text.blank?

    css_classes = ['clipboard-copy-button', css_class].compact.join ' '
    title ||= l :button_copy

    link_to_function sprite_icon(icon),
                     'copyToClipboardWithFeedback(this);',
                     class: css_classes,
                     data: { 'clipboard-text' => text },
                     title:
  end

  # Renders text with an inline clipboard copy button
  #
  # @param text [String] The text to display and make copyable
  # @param icon [String] Custom icon name (default: 'copy')
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text
  # @return [String] HTML span element with text and copy button
  #
  # @example
  #   render_text_with_clipboard('username@example.com')
  #   render_text_with_clipboard('API Key', icon: 'copy-link')
  def render_text_with_clipboard(text, icon: 'copy', css_class: nil, title: nil)
    return if text.blank?

    safe_join [tag.span(text, class: 'clipboard-text'),
               clipboard_copy_button(text, icon:, css_class:, title:)], ' '
  end

  # Renders clickable email address that copies to clipboard when clicked (no button)
  # Uses acronym tag with dotted underline style, specifically for email addresses
  #
  # @param email [String] The email address to display and make copyable
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text (default: l(:button_copy))
  # @return [String] HTML acronym element with clickable email address
  #
  # @example
  #   render_email_address_with_clipboard('user@example.com')
  def render_email_address_with_clipboard(email, css_class: nil, title: nil)
    return if email.blank?

    css_classes = ['clipboard-text', css_class].compact.join ' '
    title ||= l :button_copy

    tag.acronym email,
                class: css_classes,
                onclick: 'copyToClipboardWithFeedback(this); return false;',
                data: { 'clipboard-text' => email },
                title:
  end
end
