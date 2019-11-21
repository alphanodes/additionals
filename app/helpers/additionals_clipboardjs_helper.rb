module AdditionalsClipboardjsHelper
  def clipboardjs_button_for(target, clipboard_text_from_button = nil)
    render_clipboardjs_button(target, clipboard_text_from_button) + render_clipboardjs_javascript(target)
  end

  private

  def render_clipboardjs_button(target, clipboard_text_from_button)
    data = { 'clipboard-target' => "##{target}",
             'label-copied' => l(:label_copied_to_clipboard),
             'label-to-copy' => l(:label_copy_to_clipboard) }

    data['clipboard-text'] = clipboard_text_from_button if clipboard_text_from_button.present?

    content_tag(:button, nil,
                id: "zc_#{target}",
                class: 'clipboard_button far fa-copy',
                type: 'button',
                title: l(:label_copy_to_clipboard),
                data: data)
  end

  def render_clipboardjs_javascript(target)
    javascript_tag("setClipboardJS('#zc_#{target}');")
  end
end
