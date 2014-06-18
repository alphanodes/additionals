$(function(){
	/**
	 * New window
	 */
	var handleNewWindow = function()
	{
		this.target = '_blank';
	}

 	/**
 	 * New window with anonymizer
 	 */
 	var handleAnon = function()
 	{
 		this.href =  'http://dontknow.me/at/?' + this.href;
 	}

	$('div.attachments a, a.external').each(handleNewWindow);
	$('a.external').each(handleAnon);
});
