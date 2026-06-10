# frozen_string_literal: true

# Drop-in replacement for `form_tag(..., remote: true)` -- emits a form wired
# to the Stimulus `remote-form` controller. The controller intercepts submit,
# fetches with Accept: text/html and applies <template>-based directives.
module AdditionalsRemoteFormHelper
  def remote_form_tag(url_for_options = {}, options = {}, &)
    options[:data] = (options[:data] || {}).merge controller: 'remote-form',
                                                  action: 'submit->remote-form#submit'
    form_tag url_for_options, options, &
  end

  # Drop-in replacement for `delete_link(url, remote: true, ...)` -- emits a
  # link wired to the Stimulus `remote-form` controller's click action.
  #
  # Uses plugin-prefixed data attributes (`data-remote-method`,
  # `data-remote-confirm`) instead of `data-method` / `data-confirm` so the
  # link is not also picked up by rails-ujs's document-level delegation,
  # which would otherwise show a second confirm dialog.
  def remote_delete_link(url, options = {}, button_name = l(:button_delete))
    options[:data] = (options[:data] || {}).merge controller: 'remote-form',
                                                  action: 'click->remote-form#click',
                                                  remote_method: (options.delete(:method) || :delete).to_s,
                                                  remote_confirm: options.delete(:confirm) || l(:text_are_you_sure)
    link_to sprite_icon('del', button_name), url, options.except(:remote)
  end
end
