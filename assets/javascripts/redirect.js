// Copyright (c) 2015 AlphaNodes

$(function() {
	var handleNewWindow = function() {
		this.target = '_blank';
	}
	$('div.attachments a, a.external').each(handleNewWindow);
});
