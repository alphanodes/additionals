(function()
{
	/**
	 * New window
	 */
	 var handleNewWindow = function()
	 {
		 this.target = '_blank';
	 }
	
	// redmine uses jQuery so use it.
	jQuery(document).ready(function()
	{
		jQuery('div.attachments a, a.external').each(handleNewWindow);
	});
})();
