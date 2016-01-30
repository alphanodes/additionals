/*!
 * Redmine Tweaks plugin for Redmine
 * Copyright (C) 2013-2016 AlphaNodes GmbH
 */

$(function() {
	var handleNoReferrer = function() {
		this.rel = 'noreferrer';
	}
	$('a.external').each(handleNoReferrer);
});
