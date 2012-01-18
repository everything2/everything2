<?php
/******************************************************************************
 Mint
  
 Copyright 2004-2007 Shaun Inman. This code cannot be redistributed without
 permission from http://www.shauninman.com/
 
 More info at: http://www.haveamint.com/
 
 ******************************************************************************
 Record
 ******************************************************************************/
 if (!defined('MINT')) { header('Location:/'); }; // Prevent viewing this file 
 
header('Content-type: text/javascript');

if (isset($_COOKIE['MintIgnore']) && $_COOKIE['MintIgnore']=='true')
{
	echo '// Mint is ignoring you as requested';
	exit();
}

// used to populate the $Mint->acceptsCookies property, only lasts 15 seconds to prevent mid-session changes to cookie settings or site-framing, eg. google images
$Mint->bakeCookie('MintAcceptsCookies', 1, time() + 15);

$live_debug = isset($_COOKIE['MintLiveDebug']);

?>var Mint = new Object();
Mint.save = function() 
{
	var now		= new Date();
	var debug	= <?php echo ($live_debug) ? 'true' : 'false'; ?>; // this is set by php 
	if (window.location.hash == '#Mint:Debug') { debug = true; };
	var path	= '<?php echo $Mint->cfg['installFull']; ?>/?record&key=<?php echo $Mint->generateKey(); ?>';
	path = path.replace(/^https?:/, window.location.protocol);
	
	// Loop through the different plug-ins to assemble the query string
	for (var developer in this) 
	{
		for (var plugin in this[developer]) 
		{
			if (this[developer][plugin] && this[developer][plugin].onsave) 
			{
				path += this[developer][plugin].onsave();
			};
		};
	};
	// Slap the current time on there to prevent caching on subsequent page views in a few browsers
	path += '&'+now.getTime();
	
	// Redirect to the debug page
	if (debug) { window.open(path+'&debug&errors', 'MintLiveDebug'+now.getTime()); return; };
	
	/*@cc_on
	// IE PC appears to occasionally cache the image
	document.write('<script defer type="mint/record" src="' + path + '"></script>');
	return;
	@*/
	
	var img = new Image();
	img.src = path+'&serve_img';
};
<?php $Mint->javaScript(); ?>
Mint.save();