# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class ClipboardHelperTest < Additionals::HelperTest
  include AdditionalsClipboardHelper
  include Redmine::I18n
  include ERB::Util

  def setup
    super
    set_language_if_valid 'en'
    User.current = nil
  end

  def test_clipboard_copy_button
    html = clipboard_copy_button 'test_text'

    assert_include 'clipboard-copy-button', html
    assert_include 'data-clipboard-text="test_text"', html
    assert_include 'copyToClipboardWithFeedback', html
    assert_include 'icon--copy', html
  end

  def test_clipboard_copy_button_returns_nil_for_blank_text
    assert_nil clipboard_copy_button('')
    assert_nil clipboard_copy_button(nil)
  end

  def test_clipboard_copy_button_with_custom_icon
    html = clipboard_copy_button 'test_text', icon: 'copy-link'

    assert_include 'icon--copy-link', html
  end

  def test_clipboard_copy_button_with_custom_class
    html = clipboard_copy_button 'test_text', css_class: 'custom-class'

    assert_include 'clipboard-copy-button custom-class', html
  end

  def test_render_text_with_clipboard_with_button
    html = render_text_with_clipboard 'test@example.com'

    assert_include '<span class="clipboard-text">test@example.com</span>', html
    assert_include 'clipboard-copy-button', html
    assert_include 'copyToClipboardWithFeedback', html
  end

  def test_render_text_with_clipboard_without_button
    html = render_text_with_clipboard 'test@example.com', with_button: false

    assert_include '<acronym', html
    assert_include 'class="clipboard-text"', html
    assert_include 'onclick="copyToClipboardWithFeedback(this); return false;"', html
    assert_include 'data-clipboard-text="test@example.com"', html
    assert_include 'data-label-copied="Copied!"', html
    assert_include 'data-original-title="Copy"', html
    assert_not_include 'clipboard-copy-button', html
  end

  def test_render_text_with_clipboard_returns_nil_for_blank_text
    assert_nil render_text_with_clipboard('')
    assert_nil render_text_with_clipboard(nil)
    assert_nil render_text_with_clipboard('', with_button: false)
  end

  def test_render_text_with_clipboard_with_custom_icon
    html = render_text_with_clipboard 'test', icon: 'copy-link'

    assert_include 'icon--copy-link', html
  end

  def test_render_text_with_clipboard_with_custom_class_and_button
    html = render_text_with_clipboard 'test', css_class: 'custom'

    assert_include 'clipboard-copy-button custom', html
  end

  def test_render_text_with_clipboard_with_custom_class_without_button
    html = render_text_with_clipboard 'test', with_button: false, css_class: 'custom'

    assert_include 'class="clipboard-text custom"', html
  end

  def test_render_text_with_clipboard_for_email_without_button
    html = render_text_with_clipboard 'user@example.com', with_button: false

    assert_include '<acronym', html
    assert_include 'class="clipboard-text"', html
    assert_include 'onclick="copyToClipboardWithFeedback(this); return false;"', html
    assert_include 'data-clipboard-text="user@example.com"', html
    assert_include 'data-label-copied="Copied!"', html
    assert_include 'data-original-title="Copy"', html
    assert_include 'user@example.com</acronym>', html
  end

  def test_render_text_with_clipboard_for_email_with_custom_class
    html = render_text_with_clipboard 'user@example.com', with_button: false, css_class: 'email-custom'

    assert_include 'class="clipboard-text email-custom"', html
  end
end
