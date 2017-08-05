module AdditionalsTagHelper
  # Renders list of tags
  # Clouds are rendered as block <tt>div</tt> with internal <tt>span</t> per tag.
  # Lists are rendered as unordered lists <tt>ul</tt>. Lists are ordered by
  # <tt>tag.count</tt> descending.
  # === Parameters
  # * <i>tags</i> = Array of Tag instances
  # * <i>options</i> = (optional) Options (override system settings)
  #   * show_count  - Boolean. Whenever show tag counts
  #   * style       - list, cloud
  def render_additionals_tags_list(tags, options = {})
    return if tags.blank?

    content = ''
    style = options.delete(:style)
    style = if style.nil?
              :cloud
            else
              style.to_sym
            end

    # prevent ActsAsTaggableOn::TagsHelper from calling `all`
    # otherwise we will need sort tags after `tag_cloud`
    tags = tags.all if tags.respond_to?(:all)

    if style == :list
      list_el = 'ul'
      item_el = 'li'
    else
      list_el = 'div'
      item_el = 'span'
      tags = cloudify(tags)
    end

    content = content.html_safe
    tag_cloud tags, (1..8).to_a do |tag, weight|
      content << ' '.html_safe + content_tag(item_el,
                                             render_additionals_tag_link(tag, options),
                                             class: "tag-pass-#{weight}",
                                             style: (style == :simple_cloud ? 'font-size: 1em;' : '')) + ' '.html_safe
    end

    content_tag(list_el, content, class: 'tags', style: (style == :simple_cloud ? 'text-align: left;' : ''))
  end

  def render_additionals_tag_link_line(tags)
    s = []
    tags.each do |tag|
      s << render_additionals_tag_link(tag)
    end
    safe_join(s, ', ')
  end

  # Returns tag link
  # === Parameters
  # * <i>tag</i> = Instance of Tag
  # * <i>options</i> = (optional) Options (override system settings)
  #   * show_count  - Boolean. Whenever show tag counts
  def render_additionals_tag_link(tag, options = {})
    filters = [[:tags, '=', tag.name]]
    content = if options[:use_search]
                link_to(tag, controller: 'search', action: 'index', id: @project, q: tag.name, wiki_pages: true, issues: true)
              else
                additionals_link_to_filter(tag.name, filters, project_id: @project)
              end
    if options[:show_count]
      content << content_tag('span', " (#{tag.count})", class: 'tag-count')
    end

    style = { class: 'tag-label-color', style: "background-color: #{tag_color(tag)}" }
    content_tag('span', content, style)
  end

  def additionals_link_to_filter(title, filters, options = {})
    options.merge! additionals_link_to_filter_options(filters)
    link_to title, options
  end

  private

  def tag_cloud(tags, classes)
    return [] if tags.empty?

    max_count = tags.sort_by(&:count).last.count.to_f

    tags.each do |tag|
      index = ((tag.count / max_count) * (classes.size - 1))
      yield tag, classes[index.nan? ? 0 : index.round]
    end
  end

  def tag_color(tag)
    tag_name = tag.respond_to?(:name) ? tag.name : tag
    "##{Digest::MD5.hexdigest(tag_name)[0..5]}"
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

  def additionals_link_to_filter_options(filters)
    options = {
      controller: controller_name,
      action: 'index',
      set_filter: 1,
      fields: [],
      values: {},
      operators: {}
    }

    filters.each do |f|
      name, operator, value = f
      options[:fields].push(name)
      options[:operators][name] = operator
      options[:values][name] = [value]
    end

    options
  end
end
