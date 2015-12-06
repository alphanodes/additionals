// Copyright (c) 2015 AlphaNodes

$(function() {
	var handleNoReferrer = function() {
		this.rel = 'noreferrer';
	}
	$('a.external').each(handleNoReferrer);
});
