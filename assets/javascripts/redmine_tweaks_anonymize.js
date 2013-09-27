(function()
{
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
	
	// redmine uses jQuery so use it.

	jQuery(document).ready(function()
	{
		jQuery('div.attachments a, a.external').each(handleNewWindow);
		jQuery('a.external').each(handleAnon);
	});
})();
