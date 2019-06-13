module AdditionalsClipboardjsHelper
  def clipboardjs_button_for(target)
    render_clipboardjs_button(target) + render_clipboardjs_javascript(target)
  end

  private

  def render_clipboardjs_button(target)
    opts = { id: "zc_#{target}", class: 'clipboard_button', data: clipboardjs_options.merge('clipboard-target' => "##{target}") }
    content_tag(:div, image_tag('paste.png', plugin: 'additionals'), opts)
  end

  def render_clipboardjs_javascript(target)
    javascript_tag("setZeroClipBoard('#zc_#{target}');")
  end

  def clipboardjs_options
    { 'label-copied' => l(:label_copied_to_clipboard), 'label-to-copy' => l(:label_copy_to_clipboard) }
  end
end
