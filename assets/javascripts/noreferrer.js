$(function() {
	var handleNoReferrer = function() {
		this.rel = 'noreferrer';
	}
	$('a.external').each(handleNoReferrer);
});
