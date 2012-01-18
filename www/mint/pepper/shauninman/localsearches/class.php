<?php
/******************************************************************************
 Pepper
 
 Developer		: Shaun Inman
 Plug-in Name	: Local Searches
 
 http://www.shauninman.com/

 ******************************************************************************/
if (!defined('MINT')) { header('Location:/'); }; // Prevent viewing this file
$installPepper = "SI_LocalSearches";

class SI_LocalSearches extends Pepper
{
	var $version	= 201; 
	var $info		= array
	(
		'pepperName'	=> 'Local Searches',
		'pepperUrl'		=> 'http://www.haveamint.com/',
		'pepperDesc'	=> 'You already know how people are finding you, now know what they are still looking for once they do.',
		'developerName'	=> 'Shaun Inman',
		'developerUrl'	=> 'http://www.shauninman.com/'
	);
	var $panes		= array
	(
		'Local Searches'	=> array
		(
			'Most Common',
			'Most Recent'
		)
	);
	var $prefs		= array
	(
		'localSearchPath'		=> '',
		'localSearchQuery'		=> ''
	);
	var $manifest	= array
	(
		'visit'	=> array
		(
			'local_search_terms' => "VARCHAR(255) NOT NULL",
			'local_search_found' => "TINYINT(1) unsigned NOT NULL default '0'"
		)
	);
	
	/**************************************************************************
	 isCompatible()
	 **************************************************************************/
	function isCompatible()
	{
		if ($this->Mint->version < 200)
		{
			$compatible = array
			(
				'isCompatible'	=> false,
				'explanation'	=> '<p>This Pepper requires Mint 2, a paid upgrade, now available at <a href="http://www.haveamint.com/">haveamint.com</a>.</p>'
			);
		}
		else
		{
			$compatible = array
			(
				'isCompatible'	=> true,
			);
		}
		return $compatible;
	}
	
	/**************************************************************************
	 onRecord()
	 **************************************************************************/
	function onRecord()
	{
 		if (empty($this->prefs['localSearchPath'])) { return array(); }
 		
 		$path	= preg_quote($this->prefs['localSearchPath'], "/");
 		$query	= preg_quote($this->prefs['localSearchQuery'], "/");
 		
		$terms	= '';
		$found	= 0;
 		$referer 	= $this->escapeSQL(preg_replace('/#.*$/', '', htmlentities($_GET['referer'])));
 		$resource	= $this->escapeSQL(preg_replace('/#.*$/', '', htmlentities($_GET['resource'])));
 		
 		// Need to use siteDomains and allow for port numbers
		// if the referrer matches our local search results page
 		if (preg_match("/".$this->Mint->cfg['installTrim']."(:\d+)?{$path}[^\?]*\?(([^&]*&)*{$query}=([^&]*)&?)/i", html_entity_decode($referer), $matches)) {
 			$terms	= $this->escapeSQL(rawurldecode(htmlentities($matches[4])));
 			$found	= 1;
 			}
 		// if resource matches
 		else if (preg_match("/{$path}[^\?]*\?(([^&]*&)*{$query}=(?!cache:[^:]+:)([^&]*)&?)/i", html_entity_decode($resource), $matches)) {
 			$terms = $this->escapeSQL(rawurldecode(htmlentities($matches[3])));
 			}
 		
 		return array
 		(
 			'local_search_terms'	=> $terms,
 			'local_search_found'	=> $found
 		);
	}
	
	/**************************************************************************
	 onDisplay()
	 **************************************************************************/
	function onDisplay($pane, $tab, $column = '', $sort = '')
	{
		$html = '';
		
		switch($pane) 
		{
			/* Visitors *******************************************************/
			case 'Local Searches': 
				switch($tab) 
				{
					/* Most Common ********************************************/
					case 'Most Common':
						$html .= $this->getHTML_LocalSearchesCommon();
					break;
					/* Most Recent ********************************************/
					case 'Most Recent':
						$html .= $this->getHTML_LocalSearchesRecent();
					break;
				}
			break;
		}
		return $html;
	}
	
	/**************************************************************************
	 onDisplayPreferences()
	 **************************************************************************/
	function onDisplayPreferences() 
	{
		/* Global *************************************************************/
		$preferences['Local Searches']	= <<<HERE
<table>
	<tr>
		<th scope="row">Path</th>
		<td><span><input type="text" id="localSearchPath" name="localSearchPath" value="{$this->prefs['localSearchPath']}" /></span></td>
	</tr>
	<tr>
		<td></td>
		<td>A relative path, eg. <code>/search/</code> or <code>/search.php</code> (Don't include <code>index.*</code>)</td>
	</tr>
	<tr>
		<th scope="row">Query</th>
		<td><span><input type="text" id="localSearchQuery" name="localSearchQuery" value="{$this->prefs['localSearchQuery']}" /></span></td>
	</tr>
	<tr>
		<td></td>
		<td>The <code>q</code> in <code>/search.php?q=Mint</code> (Only works with the <code>get</code> form method)</td>
	</tr>
</table>

HERE;
		
		return $preferences;
	}
	
	/**************************************************************************
	 onSavePreferences()
	 **************************************************************************/
	function onSavePreferences() 
	{
		$this->prefs['localSearchPath']		= $this->escapeSQL($_POST['localSearchPath']);
		$this->prefs['localSearchQuery']	= $this->escapeSQL($_POST['localSearchQuery']);
	}
	
	/**************************************************************************
	 getHTML_LocalSearchesRecent()
	 **************************************************************************/
	function getHTML_LocalSearchesRecent() 
	{
		$html = '';
		
		$tableData['table'] = array('id'=>'','class'=>'');
		$tableData['thead'] = array
		(
			// display name, CSS class(es) for each column
			array('value'=>'Keywords','class'=>'focus'),
			array('value'=>'When','class'=>'sort')
		);
			
		$query = "SELECT `local_search_terms`, `local_search_found`, `referer`, `resource`, `resource_title`, `dt`
					FROM `{$this->Mint->db['tblPrefix']}visit` 
					WHERE
					`local_search_terms`!=''
					ORDER BY `dt` DESC 
					LIMIT 0,{$this->Mint->cfg['preferences']['rows']}";
		if ($result = $this->query($query))
		{
			while ($r = mysql_fetch_array($result))
			{
				$dt 			= $this->Mint->formatDateTimeRelative($r['dt']);
				$search_terms	= $this->Mint->abbr(stripslashes($r['local_search_terms']));
				$res_title		= $this->Mint->abbr((!empty($r['resource_title']))?stripslashes($r['resource_title']):$r['resource']);
				
				if ($r['local_search_found'])
				{
					$found 	= "<br /><span>Found <a href=\"{$r['resource']}\">$res_title</a></span>";
					$search	= $r['referer'];
				}
				else
				{
					$found	= '';
					$search	= $r['resource'];
				}
				$tableData['tbody'][] = array
				(
					"<a href=\"$search\" rel=\"nofollow\">$search_terms</a>".(($this->Mint->cfg['preferences']['secondary'])?$found:''),
					$dt
				);
			}
		}
			
		$html = $this->Mint->generateTable($tableData);
		return $html;
	}


	/**************************************************************************
	 getHTML_LocalSearchesCommon()
	 **************************************************************************/
	function getHTML_LocalSearchesCommon()
	{
		$html = '';
		
		$filters = array
		(
			'Show all'	=> 0,
			'Past hour'	=> 1,
			'2h'		=> 2,
			'4h'		=> 4,
			'8h'		=> 8,
			'24h'		=> 24,
			'48h'		=> 48,
			'72h'		=> 72
		);
		$html .= $this->generateFilterList('Most Common', $filters);
		$timespan = ($this->filter) ? " AND dt > ".(time() - ($this->filter * 60 * 60)) : '';
		
		$tableData['table'] = array('id'=>'','class'=>'');
		$tableData['thead'] = array
		(
			// display name, CSS class(es) for each column
			array('value'=>'Hits','class'=>'sort'),
			array('value'=>'Keywords','class'=>'focus')
		);
		
		$query = "SELECT `local_search_terms`, `local_search_found`, `referer`, `resource`, `resource_title`, COUNT(`local_search_terms`) as `total`, `dt`
					FROM `{$this->Mint->db['tblPrefix']}visit` 
					WHERE
					`local_search_terms` != '' AND
					`local_search_found` = 0 {$timespan}
					GROUP BY `local_search_terms` 
					ORDER BY `total` DESC, `dt` DESC 
					LIMIT 0,{$this->Mint->cfg['preferences']['rows']}";
		if ($result = $this->query($query))
		{
			while ($r = mysql_fetch_array($result))
			{
				$search_terms	= $this->Mint->abbr(stripslashes($r['local_search_terms']));
				$res_title		= $this->Mint->abbr((!empty($r['resource_title']))?stripslashes($r['resource_title']):$r['resource']);
				
				if ($r['local_search_found'])
				{
					$found 	= "<br /><span>Found <a href=\"{$r['resource']}\">$res_title</a></span>";
					$search	= $r['referer'];
				}
				else
				{
					$found	= '';
					$search	= $r['resource'];
				}
				$tableData['tbody'][] = array
				(
					$r['total'],
					"<a href=\"$search\" rel=\"nofollow\">$search_terms</a>".(($this->Mint->cfg['preferences']['secondary'])?$found:'')
				);
			}
		}
			
		$html .= $this->Mint->generateTable($tableData);
		return $html;
	}
}