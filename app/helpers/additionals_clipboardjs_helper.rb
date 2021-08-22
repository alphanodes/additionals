# frozen_string_literal: true

module AdditionalsClipboardjsHelper
  def clipboardjs_button_for(target, clipboard_text_from_button = nil)
    render_clipboardjs_button(target, clipboard_text_from_button) + render_clipboardjs_javascript(target)
  end

  def render_text_with_clipboardjs(text)
    return if text.blank?

    tag.acronym text,
                class: 'clipboard-text',
                title: l(:label_copy_to_clipboard),
                data: clipboardjs_data(text: text)
  end

  def clipboardjs_data(clipboard_data)
    data = { 'label-copied' => l(:label_copied_to_clipboard),
             'label-to-copy' => l(:label_copy_to_clipboard) }

    clipboard_data.each do |key, value|
      data["clipboard-#{key}"] = value if value.present?
    end

    data
  end

  private

  def render_clipboardjs_button(target, clipboard_text_from_button)
    tag.button id: "zc_#{target}",
               class: 'clipboard-button far fa-copy',
               type: 'button',
               title: l(:label_copy_to_clipboard),
               data: clipboardjs_data(target: "##{target}", text: clipboard_text_from_button)
  end

  def render_clipboardjs_javascript(target)
    javascript_tag "setClipboardJS('#zc_#{target}');"
  end
end
