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

  # Renders text with clipboard functionality
  #
  # @param text [String] The text to display and make copyable
  # @param with_button [Boolean] If true, shows text + button. If false, text is clickable (default: true)
  # @param icon [String] Custom icon name for button (default: 'copy')
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text (default: l(:button_copy))
  # @return [String] HTML element with clipboard functionality
  #
  # @example With button (default)
  #   render_text_with_clipboard('username@example.com')
  #   render_text_with_clipboard('API Key', icon: 'copy-link')
  #
  # @example Without button (clickable text for emails)
  #   render_text_with_clipboard('user@example.com', with_button: false)
  def render_text_with_clipboard(text, with_button: true, icon: 'copy', css_class: nil, title: nil)
    return if text.blank?

    title ||= l :button_copy

    if with_button
      safe_join [tag.span(text, class: 'clipboard-text'),
                 clipboard_copy_button(text, icon:, css_class:, title:)], ' '
    else
      css_classes = ['clipboard-text', css_class].compact.join ' '
      tag.acronym text,
                  class: css_classes,
                  onclick: 'copyToClipboardWithFeedback(this); return false;',
                  data: { 'clipboard-text' => text, 'label-copied' => l(:label_copied_to_clipboard), 'original-title' => title },
                  title:
    end
  end
end
