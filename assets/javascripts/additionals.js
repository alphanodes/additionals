/* exported setClipboardJS */
/* global ClipboardJS */
function setClipboardJS(element){
  var clipboard = new ClipboardJS(element);
  clipboard.on('success', function(e) {
    $(element).tooltip({
      content: $(element).data('label-copied')
    });
    setTimeout(function() {
      e.clearSelection();
      $(element).tooltip({
        content: $(element).data('label-to-copy')
      });
    }, 1000);
  });
}

/* exported openExternalUrlsInTab */
function openExternalUrlsInTab() {
  $('a.external').attr({
    'target': '_blank',
    'rel': 'noopener noreferrer'});
}

/* exported nativeEmojiSupport */
function nativeEmojiSupport(emoji_code) {
  var noEmojis = /\p{Extended_Pictographic}/u;
  return noEmojis.test(emoji_code);
}

/* exported formatNameWithIcon */
function formatNameWithIcon(opt) {
  if (opt.loading) return opt.name;
  var $opt;
  if (opt.name_with_icon !== undefined) {
    $opt = $('<span>' + opt.name_with_icon + '</span>');
  } else {
    $opt = $('<span>' + opt.text + '</span>');
  }
  return $opt;
}

/* exported formatFontawesomeText */
function formatFontawesomeText(icon) {
  var icon_id = icon.id;
  if (icon_id !== undefined) {
    var fa = icon.id.split('_');
    return $('<span><i class="' + fa[0] + ' fa-' + fa[1] + '"></i> ' + icon.text + '</span>');
  } else {
    return icon.text;
  }
}

/* exported observeLiveSearchField */
function observeLiveSearchField(fieldId, targetId, target_url) {
  $('#'+fieldId).each(function() {
    var $this = $(this);
    $this.addClass('autocomplete');
    $this.attr('data-search-was', $this.val());
    var check = function() {
      var val = $this.val();
      if ($this.attr('data-search-was') != val){
        $this.attr('data-search-was', val);

        var form = $('#query_form'); // grab the form wrapping the search bar.
        var formData;
        var url;

        form.find('[name="c[]"] option').each(function(i, elem) {
          $(elem).attr('selected', true);
        });

        if (typeof target_url === 'undefined') {
          url = form.attr('action');
          formData = form.serialize();
        } else {
          url = target_url;
          formData = { q: val };
        }

        form.find('[name="c[]"] option').each(function(i, elem) {
          $(elem).attr('selected', false);
        });

        $.ajax({
          url: url,
          data: formData,
          success: function(data) { if(targetId) $('#'+targetId).html(data); },
          beforeSend: function() { $this.addClass('ajax-loading'); },
          complete: function() { $this.removeClass('ajax-loading'); }
        });
      }
    };

    /* see https://stackoverflow.com/questions/1909441/how-to-delay-the-keyup-handler-until-the-user-stops-typing */
    var search_delay = function(callback) {
      var timer = 0;
      return function() {
        var context = this, args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function() {
          callback.apply(context, args);
        }, 400 || 0);
      };
    };

    $this.keyup(search_delay(check));
  });
}

/* Use this instead of showTab from Redmine, because on tabs are supported for plugin settings */
/* exported showPluginSettingsTab */
/* global replaceInHistory */
function showPluginSettingsTab(name, url) {
  $('#tab-content-' + name).parent().find('.tab-content').hide();
  $('#tab-content-' + name).show();
  $('#tab-' + name).closest('.tabs').find('a').removeClass('selected');
  $('#tab-' + name).addClass('selected');

  replaceInHistory(url);

  /* only changes to this function */
  var form = $('#tab-' + name).closest('form');
  addTabToFromAction(form, name);
  /* change end */

  return false;
}

function addTabToFromAction(form, name) {
  form.attr('action', function(i, action) {
    if (action.includes('tab=')) {
      return action.replace(/([?&])(tab=)[^&#]*/, '$1$2' + name);
    } else if (!action.includes('?')) {
      return action + '?tab=' + name;
    } else if (!action.includes(name)) {
      return action + '&tab=' + name;
    }
  });

  /* console.log('hack it for: ' + name + ' with action ' + form.attr('action')); */
}
