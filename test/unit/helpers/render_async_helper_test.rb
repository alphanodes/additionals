# frozen_string_literal: true

require File.expand_path '../../../test_helper', __FILE__

class RenderAsyncHelperTest < Additionals::HelperTest
  include AdditionalsRenderAsyncHelper
  include Redmine::I18n
  include ERB::Util

  def test_render_async_cache_key
    assert_equal 'render_async_/foo/bar', render_async_cache_key('/foo/bar')
  end

  def test_render_async_emits_stimulus_controlled_div
    html = render_async '/dashboards/123/async_blocks'

    assert_include 'data-controller="render-async"', html
    assert_include 'data-render-async-url-value="/dashboards/123/async_blocks"', html
    assert_match(/<div\b/, html)
  end

  def test_render_async_uses_custom_html_element_name
    html = render_async '/path', html_element_name: 'tr'

    assert_match(/<tr\b/, html)
  end

  def test_render_async_emits_interval_value
    html = render_async '/path', interval: 5000

    assert_include 'data-render-async-interval-value="5000"', html
  end

  def test_render_async_skips_interval_for_blank_or_zero
    html_blank = render_async '/path'
    html_zero  = render_async '/path', interval: 0

    assert_not_include 'render-async-interval-value', html_blank
    assert_not_include 'render-async-interval-value', html_zero
  end

  def test_render_async_emits_toggle_values
    html = render_async '/path', toggle: { selector: '#trigger', event: :click }

    assert_include 'data-render-async-toggle-selector-value="#trigger"', html
    assert_include 'data-render-async-toggle-event-value="click"', html
  end

  def test_render_async_emits_lazy_value
    html = render_async '/path', lazy: true

    assert_include 'data-render-async-lazy-value="true"', html
  end

  def test_render_async_emits_min_height_style
    html = render_async '/path', min_height: 400

    assert_include 'style="min-height:400px"', html
  end

  def test_render_async_skips_min_height_for_zero_or_blank
    html_blank = render_async '/path'
    html_zero  = render_async '/path', min_height: 0

    assert_not_include 'min-height', html_blank
    assert_not_include 'min-height', html_zero
  end

  def test_render_async_skips_lazy_value_when_not_set
    html_default = render_async '/path'
    html_false   = render_async '/path', lazy: false

    assert_not_include 'render-async-lazy-value', html_default
    assert_not_include 'render-async-lazy-value', html_false
  end

  def test_render_async_emits_error_message_value
    html = render_async '/path', error_message: '<p>boom</p>'

    assert_include 'data-render-async-error-message-value="&lt;p&gt;boom&lt;/p&gt;"', html
  end

  def test_render_async_captures_block_as_placeholder
    html = render_async('/path') { '<span class="spinner">loading</span>'.html_safe }

    assert_include '<span class="spinner">loading</span>', html
  end

  def test_render_async_uses_explicit_container_id_when_given
    html = render_async '/path', container_id: 'my-container'

    assert_include 'id="my-container"', html
  end

  def test_render_async_cache_falls_through_when_cache_empty
    Rails.cache.expects(:read).with("views/#{render_async_cache_key '/uncached'}").returns(nil)

    html = render_async_cache '/uncached'

    assert_include 'data-controller="render-async"', html
    assert_include 'data-render-async-url-value="/uncached"', html
  end

  def test_render_async_cache_returns_cached_view_when_present
    Rails.cache.expects(:read).with("views/#{render_async_cache_key '/cached'}").returns('<p>from cache</p>')

    html = render_async_cache '/cached'

    assert_equal '<p>from cache</p>', html
    assert_predicate html, :html_safe?
  end
end
