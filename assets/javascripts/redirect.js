/*!
 * Redmine Tweaks plugin for Redmine
 * Copyright (C) 2013-2017 AlphaNodes GmbH
 */

$(function() {
	var handleNewWindow = function() {
		this.target = '_blank';
	}
	$('div.attachments a, a.external').each(handleNewWindow);
});
