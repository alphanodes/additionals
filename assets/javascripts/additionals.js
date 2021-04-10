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

/* exported formatNameWithIcon */
function formatNameWithIcon(opt) {
  if (opt.loading) return opt.name;
  var $opt = $('<span>' + opt.name_with_icon + '</span>');
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
          type: 'get',
          data: formData,
          success: function(data){ if(targetId) $('#'+targetId).html(data); },
          beforeSend: function(){ $this.addClass('ajax-loading'); },
          complete: function(){ $this.removeClass('ajax-loading'); }
        });
      }
    };

    /* see https://stackoverflow.com/questions/1909441/how-to-delay-the-keyup-handler-until-the-user-stops-typing */
    var search_delay = function(callback) {
      var timer = 0;
      return function() {
        var context = this, args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function () {
          callback.apply(context, args);
        }, 400 || 0);
      };
    };

    $this.keyup(search_delay(check));
  });
}
