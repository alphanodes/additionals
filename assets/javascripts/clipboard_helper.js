function setZeroClipBoard(element){
  $(element).tooltip({
    title: $(element).data('label-to-copy'),
    placement: 'right'
  });

  var clipboard = new ClipboardJS(element);

  clipboard.on('success', function(e) {
    setTooltip(e.trigger, $(element).data('label-copied'));
    hideTooltip(e.trigger);
  });
}

// Tooltip
function setTooltip(btn, message) {
  $(btn).tooltip('hide')
    .attr('data-original-title', message)
    .tooltip('show');
}

function hideTooltip(btn) {
  setTimeout(function() {
    $(btn).tooltip('hide');
  }, 1000);
}
