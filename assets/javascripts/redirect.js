$(function() {
	var handleNewWindow = function() {
		this.target = '_blank';
	}
	$('div.attachments a, a.external').each(handleNewWindow);
});
