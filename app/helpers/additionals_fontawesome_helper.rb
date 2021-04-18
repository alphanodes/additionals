# frozen_string_literal: true

module AdditionalsFontawesomeHelper
  # name = TYPE-FA_NAME, eg. fas_car
  #                          fas_cloud-upload-alt
  #                          far_id-card
  #                          fab_font-awesome
  # options = class
  #           pre_text
  #           post_text
  #           title
  def font_awesome_icon(name, **options)
    info = AdditionalsFontAwesome.value_info name
    return '' if info.blank?

    post_text = ''
    options[:'aria-hidden'] = 'true'
    options[:class] = if options[:class].present?
                        "#{info[:classes]} #{options[:class]}"
                      else
                        info[:classes]
                      end

    s = []
    if options[:pre_text].present?
      s << options[:pre_text]
      s << ' '
      options.delete :pre_text
    end
    if options[:post_text].present?
      post_text = options[:post_text]
      options.delete :post_text
    end
    s << tag.span(**options)
    if post_text.present?
      s << ' '
      s << post_text
    end
    safe_join s
  end

  def additionals_fontawesome_select(form, selected, **options)
    options[:include_blank] ||= true unless options[:required]
    html_options = {}

    additionals_fontawesome_add_selected selected

    name, options = Additionals.hash_remove_with_default :name, options, :icon
    loader, options = Additionals.hash_remove_with_default :loader, options, true
    html_options[:class], options = Additionals.hash_remove_with_default :class, options, 'select2-fontawesome-field'
    html_options[:style], options = Additionals.hash_remove_with_default :style, options

    s = []
    s << form.select(name,
                     options_for_select(AdditionalsFontAwesome.active_option_for_select(selected), selected),
                     options,
                     html_options)

    s << additionals_fontawesome_loader(**options, field_class: html_options[:class]) if loader

    safe_join s
  end

  def additionals_fontawesome_add_selected(selected)
    @selected_store ||= []
    return if selected.blank?

    @selected_store << selected
  end

  def additionals_fontawesome_default_select_width
    '250px'
  end

  def additionals_fontawesome_loader(field_class: 'select2-fontawesome-field', **options)
    options[:template_selection] = 'formatFontawesomeText'
    options[:template_result] = 'formatFontawesomeText'
    if options[:include_blank]
      options[:placeholder] ||= l :label_disabled
      options[:allow_clear] ||= true
    end
    options[:width] = additionals_fontawesome_default_select_width

    render layout: false,
           partial: 'additionals/select2_ajax_call',
           formats: [:js],
           locals: { field_class: field_class,
                     ajax_url: fontawesome_auto_completes_path(selected: @selected_store.join(',')),
                     options: options }
  end
end
