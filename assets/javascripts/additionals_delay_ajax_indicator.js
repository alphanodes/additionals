function delayAjaxIndicator() {
  $(document).off('ajaxSend').bind('ajaxSend', function(event, xhr, settings) {
  if ($('.ajax-loading').length === 0 && settings.contentType != 'application/octet-stream') {
    $('#ajax-indicator').stop(true, false).delay(300).show(0);
  }
  });

  $(document).off('ajaxStop').bind('ajaxStop', function() {
    $('#ajax-indicator').hide(0);
  });

};

$(document).ready(delayAjaxIndicator)
