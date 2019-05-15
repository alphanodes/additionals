module AdditionalsFontawesomeHelper
  def fontawesome_info_url
    s = []
    s << l(:label_set_icon_from)
    s << link_to('https://fontawesome.com/icons?m=free', 'https://fontawesome.com/icons?m=free', class: 'external')
    safe_join(s, ' ')
  end

  # name = TYPE-FA_NAME, eg. fas_car
  #                          fas_cloud-upload-alt
  #                          far_id-card
  #                          fab_font-awesome
  # options = class
  #           pre_text
  #           post_text
  #           title
  def font_awesome_icon(name, options = {})
    info = AdditionalsFontAwesome.value_info(name)
    return '' if info.blank?

    post_text = ''
    options['aria-hidden'] = 'true'
    options[:class] = if options[:class].present?
                        info[:classes] + ' ' + options[:class]
                      else
                        info[:classes]
                      end

    s = []
    if options[:pre_text].present?
      s << options[:pre_text]
      s << ' '
      options.delete(:pre_text)
    end
    if options[:post_text].present?
      post_text = options[:post_text]
      options.delete(:post_text)
    end
    s << content_tag('span', '', options)
    if post_text.present?
      s << ' '
      s << post_text
    end
    safe_join(s)
  end
end
