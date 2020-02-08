/* exported openExternalLink */
function openExternalLink() {
  var handleNewWindow = function() {
    this.target = '_blank';
    this.rel = 'noopener';
  };
  $('div.attachments a, a.external').each(handleNewWindow);
}

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
