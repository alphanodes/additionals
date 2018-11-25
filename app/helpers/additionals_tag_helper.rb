module AdditionalsTagHelper
  # deprecated: this will removed after a while
  def render_additionals_tags_list(tags, options = {})
    additionals_tag_cloud(tags, options)
  end

  # deprecated: this will removed after a while
  def render_additionals_tag_link_line(tag_list)
    additionals_tag_links(tag_list)
  end

  def additionals_tag_cloud(tags, options = {})
    return if tags.blank?

    options[:show_count] = true

    # prevent ActsAsTaggableOn::TagsHelper from calling `all`
    # otherwise we will need sort tags after `tag_cloud`
    tags = tags.all if tags.respond_to?(:all)

    s = []
    tag_cloud(cloudify(tags), (1..8).to_a) do |tag, weight|
      s << content_tag(:span,
                       additionals_tag_link(tag, options),
                       class: "tag-pass-#{weight}")
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
    if options[:show_count]
      tag_name << ' '
      tag_name << content_tag('span', "(#{tag.count})", class: 'tag-count')
    end

    if options[:tags_without_color]
      content_tag('span',
                  link_to(safe_join(tag_name), additionals_tag_url(tag.name)),
                  class: 'tag-label')
    else
      content_tag('span',
                  link_to(safe_join(tag_name), additionals_tag_url(tag.name)),
                  class: 'additionals-tag-label-color',
                  style: "background-color: #{additionals_tag_color(tag.name)}")
    end
  end

  def additionals_tag_url(tag_name, options = {})
    { controller: controller_name,
      action: action_name,
      set_filter: 1,
      project_id: @project,
      fields: [:tags],
      values: { tags: [tag_name] },
      operators: { tags: '=' } }.merge(options)
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
    "##{'%06x' % (tag_name.unpack('H*').first.hex % 0xffffff)}"
  end

  def cloudify(tags)
    new_tags = []
    trigger = true
    tags.each do |tag|
      new_tags.send((trigger ? 'push' : 'unshift'), tag)
      trigger = !trigger
    end
    new_tags
  end
end
