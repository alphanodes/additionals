/* exported openExternalUrlsInTab */
function openExternalUrlsInTab() {
  $('a.external').attr({
    'target': '_blank',
    'rel': 'noopener noreferrer'});
}

/* exported nativeEmojiSupport */
function nativeEmojiSupport(emoji_code) {
  const noEmojis = /\p{Extended_Pictographic}/u;
  return noEmojis.test(emoji_code);
}

/* exported formatNameWithIcon */
function formatNameWithIcon(opt) {
  if (opt.loading) {return opt.name;}
  let $opt;
  if (opt.name_with_icon !== undefined) {
    $opt = $(`<span>${  opt.name_with_icon  }</span>`);
  } else {
    $opt = $(`<span>${  opt.text  }</span>`);
  }
  return $opt;
}

/* exported formatFontawesomeText */
function formatFontawesomeText(icon) {
  const icon_id = icon.id;
  if (icon_id !== undefined) {
    const fa = icon.id.split('_');
    return $(`<span><i class="${  fa[0]  } fa-${  fa[1]  }"></i> ${  icon.text  }</span>`);
  } else {
    return icon.text;
  }
}

/* exported observeLiveSearchField */
function observeLiveSearchField(fieldId, targetId, target_url) {
  $(`#${fieldId}`).each(function() {
    const $this = $(this);
    $this.addClass('livesearch');
    $this.attr('data-search-was', $this.val());
    const check = function() {
      const val = $this.val();
      if ($this.attr('data-search-was') !== val) {
        $this.attr('data-search-was', val);

        const form = $('#query_form'); // grab the form wrapping the search bar.
        let formData;
        let url;

        form.find('[name="c[]"] option').each((i, elem) => {
          $(elem).prop('selected', true);
        });

        if (typeof target_url === 'undefined') {
          url = form.attr('action');
          formData = form.serialize();
        } else {
          url = target_url;
          formData = { q: val };
        }

        form.find('[name="c[]"] option').each((i, elem) => {
          $(elem).prop('selected', false);
        });

        $.ajax({
          url,
          data: formData,
          success(data) { if(targetId) {$(`#${targetId}`).html(data);} },
          beforeSend() { $this.addClass('ajax-loading'); },
          complete() { $this.removeClass('ajax-loading'); }
        });
      }
    };

    /* see https://stackoverflow.com/questions/1909441/how-to-delay-the-keyup-handler-until-the-user-stops-typing */
    const search_delay = function(callback) {
      let timer = 0;
      return function() {
        const context = this, args = arguments;
        clearTimeout(timer);
        timer = setTimeout(() => {
          callback.apply(context, args);
        }, 400);
      };
    };

    $this.on('input', search_delay(check));
  });
}

/* Use this instead of showTab from Redmine, because on tabs are supported for plugin settings */
/* exported showPluginSettingsTab */
/* global replaceInHistory */
function showPluginSettingsTab(name, url) {
  $(`#tab-content-${  name}`).parent().find('.tab-content').hide();
  $(`#tab-content-${  name}`).show();
  $(`#tab-${  name}`).closest('.tabs').find('a').removeClass('selected');
  $(`#tab-${  name}`).addClass('selected');

  replaceInHistory(url);

  /* only changes to this function */
  const form = $(`#tab-${  name}`).closest('form');
  addTabToFromAction(form, name);
  /* change end */

  return false;
}

function addTabToFromAction(form, name) {
  form.attr('action', (i, action) => {
    if (action.includes('tab=')) {
      return action.replace(/([?&])(tab=)[^&#]*/, `$1$2${  name}`);
    } else if (!action.includes('?')) {
      return `${action  }?tab=${  name}`;
    } else if (!action.includes(name)) {
      return `${action  }&tab=${  name}`;
    }
  });

  /* console.log('hack it for: ' + name + ' with action ' + form.attr('action')); */
}
