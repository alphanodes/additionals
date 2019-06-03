require 'digest/md5'

module AdditionalsTagHelper
  def additionals_tag_cloud(tags, options = {})
    return if tags.blank?

    options[:show_count] = true

    # prevent ActsAsTaggableOn::TagsHelper from calling `all`
    # otherwise we will need sort tags after `tag_cloud`
    tags = tags.all if tags.respond_to?(:all)

    s = []
    tags.each do |tag|
      s << additionals_tag_link(tag, options)
    end

    sep = if options[:tags_without_color]
            ', '
          else
            ' '
          end

    content_tag(:div, safe_join(s, sep), class: 'tags')
  end

  # plain list of tags
  def render_additionals_tags(tags, sep = ' ')
    s = if tags.blank?
          ['']
        else
          tags.map(&:name)
        end
    s.join(sep)
  end

  def additionals_tag_links(tag_list, options = {})
    return unless tag_list

    sep = if options[:tags_without_color]
            ', '
          else
            ' '
          end

    safe_join(tag_list.map do |tag|
      additionals_tag_link(tag, options)
    end, sep)
  end

  def additionals_tag_link(tag, options = {})
    tag_name = []
    tag_name << tag.name

    unless options[:tags_without_color]
      tag_bg_color = additionals_tag_color(tag.name)
      tag_fg_color = additionals_tag_fg_color(tag_bg_color)
      tag_style = "background-color: #{tag_bg_color}; color: #{tag_fg_color}"
    end

    tag_name << content_tag('span', "(#{tag.count})", class: 'tag-count') if options[:show_count]

    if options[:tags_without_color]
      content_tag('span',
                  link_to(safe_join(tag_name), additionals_tag_url(tag.name, options)),
                  class: 'tag-label')
    else
      content_tag('span',
                  link_to(safe_join(tag_name),
                          additionals_tag_url(tag.name, options),
                          style: tag_style),
                  class: 'additionals-tag-label-color',
                  style: tag_style)
    end
  end

  def additionals_tag_url(tag_name, options = {})
    action = options[:tag_action].presence || (controller_name == 'hrm_user_resources' ? 'show' : 'index')

    { controller: options[:tag_controller].presence || controller_name,
      action: action,
      set_filter: 1,
      project_id: options[:project],
      fields: [:tags],
      values: { tags: [tag_name] },
      operators: { tags: '=' } }
  end

  private

  def tag_cloud(tags, classes)
    return [] if tags.empty?

    max_count = tags.max_by(&:count).count.to_f

    tags.each do |tag|
      index = ((tag.count / max_count) * (classes.size - 1))
      yield tag, classes[index.nan? ? 0 : index.round]
    end
  end

  def additionals_tag_color(tag_name)
    "##{Digest::MD5.hexdigest(tag_name)[0..5]}"
  end

  def additionals_tag_fg_color(bg_color)
    # calculate contrast text color according to YIQ method
    # https://24ways.org/2010/calculating-color-contrast/
    # https://stackoverflow.com/questions/3942878/how-to-decide-font-color-in-white-or-black-depending-on-background-color
    r = bg_color[1..2].hex
    g = bg_color[3..4].hex
    b = bg_color[5..6].hex
    (r * 299 + g * 587 + b * 114) >= 128_000 ? 'black' : 'white'
  end
end
