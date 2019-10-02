/* exported openExternalLink */
function openExternalLink() {
  var handleNewWindow = function() {
    this.target = '_blank';
    this.rel = 'noopener';
  };
  $('div.attachments a, a.external').each(handleNewWindow);
}

/* exported setClipboardJS */
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
