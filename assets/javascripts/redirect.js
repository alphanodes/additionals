$(function() {
	var handleNewWindow = function() {
		this.target = '_blank';
		this.rel = 'noopener';
	}
	$('div.attachments a, a.external').each(handleNewWindow);
});
