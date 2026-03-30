# frozen_string_literal: true

module AdditionalsClipboardHelper
  # Creates a button that copies text to clipboard
  #
  # @param text [String] The text to copy to clipboard
  # @param icon [String] Custom icon name (default: 'copy')
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text (default: l(:button_copy))
  # @return [String] HTML button element
  def clipboard_copy_button(text, icon: 'copy', css_class: nil, title: nil)
    return if text.blank?

    css_classes = ['clipboard-copy-button', css_class].compact.join ' '
    title ||= l :button_copy

    tag.a sprite_icon(icon),
          href: '#',
          class: css_classes,
          title:,
          data: { controller: 'clipboard-feedback',
                  action: 'click->clipboard-feedback#copy',
                  'clipboard-feedback-text-value': text }
  end

  # Renders text with clipboard functionality
  #
  # @param text [String] The text to display and make copyable
  # @param with_button [Boolean] If true, shows text + button. If false, text is clickable (default: true)
  # @param icon [String] Custom icon name for button (default: 'copy')
  # @param css_class [String] Additional CSS classes
  # @param title [String] Tooltip text (default: l(:button_copy))
  # @return [String] HTML element with clipboard functionality
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
                  title:,
                  data: { controller: 'clipboard-feedback',
                          action: 'click->clipboard-feedback#copy',
                          'clipboard-feedback-text-value': text,
                          'clipboard-feedback-copied-label-value': l(:label_copied_to_clipboard),
                          'clipboard-feedback-original-title-value': title }
    end
  end
end
