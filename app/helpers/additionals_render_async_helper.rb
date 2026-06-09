# frozen_string_literal: true

require 'securerandom'

# Drop-in replacement helpers for the render_async gem.
# Emits a Stimulus-controlled wrapper that loads its HTML asynchronously.
module AdditionalsRenderAsyncHelper
  RENDER_ASYNC_CACHE_PREFIX = 'render_async_'

  def render_async_cache_key(path)
    "#{RENDER_ASYNC_CACHE_PREFIX}#{path}"
  end

  def render_async_cache(path, **, &)
    cached_view = Rails.cache.read "views/#{render_async_cache_key path}"
    return render_async(path, **, &) if cached_view.blank?

    # Cache content is rendered server-side by our own controller code.
    cached_view.html_safe # rubocop:disable Rails/OutputSafety
  end

  def render_async(path, **options, &block)
    tag_name = options[:html_element_name].presence&.to_sym || :div
    container_id = options[:container_id].presence || "render_async_#{SecureRandom.hex 5}"
    container_class = options[:container_class]

    placeholder = block ? capture(&block) : ''

    data_attrs = { controller: 'render-async',
                   'render-async-url-value' => path }

    interval = options[:interval]
    data_attrs['render-async-interval-value'] = interval if interval.to_i.positive?

    toggle = options[:toggle]
    if toggle.is_a? Hash
      data_attrs['render-async-toggle-selector-value'] = toggle[:selector] if toggle[:selector].present?
      data_attrs['render-async-toggle-event-value'] = toggle[:event].to_s if toggle[:event].present?
    end

    error_message = options[:error_message]
    data_attrs['render-async-error-message-value'] = error_message if error_message.present?

    content_tag tag_name,
                placeholder,
                id: container_id,
                class: container_class,
                data: data_attrs
  end
end
