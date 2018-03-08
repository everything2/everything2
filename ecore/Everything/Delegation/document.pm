package Everything::Delegation::document;

use strict;
use warnings;

# Used by advanced_settings
use DateTime;

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseCode = *Everything::HTML::parseCode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *isMobile = *Everything::HTML::isMobile;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup;
  *encodeHTML = *Everything::HTML::encodeHTML;
}

sub document_25
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
 
  my $OUTPUT = htmlcode("ennchoice");
  $OUTPUT .= qq|<br>(see also [Writeups by Type])<br><br>|;
  $OUTPUT .= qq|<p ALIGN=LEFT><p></p></ul>|;
  $OUTPUT .= qq|<table cellpadding=0 cellspacing=0 width=100%>|.htmlcode("newnodes","25").qq|</table>|;
  return $OUTPUT; 
}

sub a_year_ago_today
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="center">Turn the clock back!</p><br><br>|;
  return $str."Don't be chatting here, show some reverence.  Besides, this page ain't cheap!" if ($query->param('op') eq 'message');

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year+=1900;
  my $yearsago = $query->param('yearsago');
  $yearsago =~ s/[^0-9]//g;
  $yearsago||=1;

  my $startat = $query->param('startat');
  $startat =~ s/[^0-9]//g;
  $startat ||=0;

  my $limit = 'type_nodetype='.getId(getType('writeup'))." and createtime > (CURDATE() - INTERVAL $yearsago YEAR) and createtime < ((CURDATE() - INTERVAL $yearsago YEAR) + INTERVAL 1 DAY)";

  my $cnt = $DB->sqlSelect('count(*)', 'node', $limit);
  my $csr = $DB->sqlSelectMany('node_id', 'node', "$limit order by createtime  limit $startat,50");

  $str.='<ul>';
  while(my $row = $csr->fetchrow_hashref())
  {

    my $wu = getNodeById($$row{node_id});
    my $parent = getNodeById($$wu{parent_e2node});
    my $author = getNodeById($$wu{author_user});
    $str.='<li>('.linkNode($parent,"full").') - '.linkNode($wu, $$parent{title})." by ".linkNode($author)." <small>entered on ".htmlcode("parsetimestamp",$$wu{createtime})."</small></li>";

  }

  $str = "$cnt writeups submitted ".(($yearsago == 1)?("a year"):("$yearsago years"))." ago today".$str;
  my $firststr = "$startat-".($startat+50);
  $str.="<p align=\"center\"><table width=\"70%\"><tr>";
  $str.="<td width=\"50%\" align=\"center\">";
  if(($startat-50) >= 0){
     $str.=linkNode($NODE,$firststr,{"startat" => ($startat-50),"yearsago" => $yearsago});
  }else{
     $str.=$firststr;
  }
  $str.="</td>";
  $str.="<td width=\"50%\" align=\"center\">";
  my $secondstr = ($startat+50)."-".(($startat + 100 < $cnt)?($startat+100):($cnt));

  if(($startat+50) <= ($cnt)){
     $str.=linkNode($NODE,$secondstr,{"startat" => ($startat+50), "yearsago" => $yearsago});
  }else{
     $str.="(end of list)";
  }

  $str.="</td>";
  $str.="</tr></table></p>";
  $str.="<p align=\"center\"><hr width=\"200\"></p>";
  $str.="<p align=\"center\">";
  my @years;
  for(1999..($year-1))
  {
    push @years,(($yearsago == ($year-$_))?("$_"):(linkNode($NODE, "$_",{"yearsago" => ($year-$_)})));
  }
  $str.= join " | ", reverse(@years);
  $str.="</p>";
  return $str;
}

sub about_nobody
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<br><br><p><center><table width="40%"><tr><td><i>About Nobody</i><p>|;
  
  my $iterations = 20;
  my @verbs = (
    'talks about',
    'broke',
    'walked',
    'saw you do',
    'cares about',
    'drew on',
    'can breathe under',
    'remembers',
    'cleaned up',
    'does',
    'fell on',
    'thinks badly of',
    'picks up',
    'eats'
  );

  my @dirobj = (
    'questions',
    'you',
    'the vase',
    'the dog',
    'the walls',
    'water',
    'last year',
    'the yard',
    'Algebra',
    'the sidewalk',
    'you',
    'the slack'
  );

  while ($iterations--)
  {
    $str .= "Nobody " . $verbs[rand(@verbs)] . ' ' .  $dirobj[rand(@dirobj)] . ".<br>";
  }
  $str .= "</td></table><br>and on and on [about Nobody].<p align=right>Andrew Lang/[nate|Nate Oostendorp]";
  return $str;
}

sub admin_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<p>You need to sign in or '
	.linkNode(getNode('Sign up','superdoc'), 'register').' to use this page.</p>' if $APP->isGuest($USER);

  $PAGELOAD->{pageheader} = '<!-- at end -->'.htmlcode('settingsDocs');

  my $str = htmlcode('openform', -id => 'pagebody');

  #editor options
  if($APP->isEditor($USER))
  {
    return unless $APP->isEditor($USER);
    my $nl = "<br />\n";
    $str .= "<p><strong>Editor Stuff</strong>\n";
    $str .= $nl . htmlcode('varcheckbox','killfloor_showlinks,Add HTML in the killing floor display for easy copy & paste');

    $str .= $nl . htmlcode('varcheckbox','hidenodenotes,Hide Node Notes');

    $str .= '</p>';

    my $f = $query->param('sexisgood'); #end of form indicator
    my $l=768; #max length of each macro

    #key is allowed macro, value is the default
    #note: things like $1 are NOT supposed to be interpolated - that is done when the macro is executed
    my %allowedMacros = (
      'room' => '/say /msg $1 Just so you know - you are not in the default room, where most people stay. To get back into the main room, either visit {go outside}, or: go to the top of the "other users" nodelet, pick "outside" from the dropdown list, and press the "Go" button.',
      'newbie' => '/say /msg $1 Hello, your writeups could use a little work. Read [Everything University] and [Everything FAQ] to improve your current and future writeups. $2+'."\n".'/say /msg $1 If you have any questions, you can send me a private message by typing this in the chatterbox: /msg $0 (Your message here.)',
      'html' => '/say /msg $1 Your writeups could be improved by using some HTML tags, such as &lt;p&gt; , which starts a new paragraph. [Everything FAQ: Can I use HTML in my writeups?] lists the tags allowed here, and [E2 HTML tags] shows you how to use them.',
      'wukill' => '/say /msg $1 FYI - I removed your writeup $2+',
      'nv' => '/say /msg $1 Hey, I know that you probably didn\'t mean to, but advertising your writeups ("[nodevertising]") in the chatterbox isn\'t cool. Imagine if everyone did that - there would be no room for chatter.',
      'misc1' => '/say /msg $0 Use this for your own custom macro. See [macro FAQ] for information about macros.'."\n".'/say /msg $0 If you have an idea of another thing to add that would be wanted by many people, give N-Wing a /msg.',
      'misc2' => '/say /msg $0 Yup, this is an area for another custom macro.'
    );

    my @ks = sort(keys(%allowedMacros));

    foreach my $k (@ks)
    {
      my $v = undef;
      if( (defined $query->param('usemacro_'.$k)) && ($v=$query->param('usemacro_'.$k) eq '1') )
      {
	#possibly add macro
	if( (defined $query->param('macrotext_'.$k)) && ($v=$query->param('macrotext_'.$k)) )
        {
          $v =~ tr/\r/\n/; $v =~ s/\n+/\n/gs; #line endings are a pain
          $v =~ s/[^\n\x20-\x7e]//gs; #could probably also allow \x80-\xfe
          $v = substr($v,0,$l);
          $v =~ s/\{/[/gs; $v =~ s/\}/]/gs; #hack - it seems you can't use square brackets in a superdoc :(
          $$VARS{'chatmacro_'.$k} = $v;
	}
      } elsif($f) {
        #delete unwanted macro (but only if no form submit problems)
        delete $$VARS{'chatmacro_'.$k};
      }
    }

    $str .= '<p><strong>Macros</strong></p>'."\n".'<table cellspacing="1" cellpadding="2" border="1"><tr><th>Use?</th><th>Name</th><th>Text</th></tr>'."\n";

    foreach my $k (@ks)
    {
	my $v = $$VARS{'chatmacro_'.$k};
	my $z = ($v && length($v)>0) ? 1 : 0;
	unless($z) { $v = $allowedMacros{$k}; }
	$v =~ s/\[/{/gs; $v =~ s/\]/}/gs; #square-link-in-superdoc workaround :(
	$str .= '<tr><td>' .
	$query->checkbox('usemacro_'.$k, $z, '1', '')
	. '</td><td><code>' . $k . '</code></td><td>' .
	$query->textarea(-name=>'macrotext_'.$k, -default=>$v, -rows=>6, -columns=>65, -override=>1)
	. "</td></tr>\n";
    }

    $str .= "</table>\n".'If you will use a macro, make sure the "Use" column is checked. If you won\'t use it, uncheck it, and it will be deleted. The text in the "macro" area of a "non-use" macro is the default text, although you can change it (but be sure to check the "use" checkbox if you want to keep it). Each macro must currently begin with <code>/say</code> (which indicates that you\'re saying something). Note: each macro is limited to '.$l.' characters. Sorry, until a better solution is found, instead of square brackets, &#91; and &#93;, you\'ll have to use curly brackets, { and } instead. <tt>:(</tt> There is more information about macros at [macro FAQ].</p>';

  }

  $str .= htmlcode("closeform");
  return $str;
}

sub advanced_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<p>You need to sign in or '
	.linkNode(getNode('Sign up','superdoc'), 'register')
	.' to use this page.</p>' if ($APP->isGuest($USER));

  if (defined $query->param('sexisgood'))
  {
    $$VARS{'preference_last_update_time'} = DateTime->now()->epoch()-60;
  }

  $PAGELOAD->{pageheader} = '<!-- put at end -->'.htmlcode('settingsDocs');
  my $str = htmlcode('openform', -id=>'pagebody');
  $str .= qq|<h2>Page display</h2>|;

  my @headeroptions = ( 'audio', 'length' , 'hits' , 'dtcreate' ) ;
  my @footeroptions = ( 'kill' , 'sendmsg' , 'addto' , 'social' ) ;

  my $legacycheck = '^$|c:type,c:(author|pseudoanon)(,\w:' . join( ')?(,\w:' , @headeroptions ) . ',?)?' ;
  my $legacyhead = '';
  $legacyhead = '<p>'.$query->checkbox(-name=>'replaceoldheader',
    -label=>'Overwrite all existing header settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)')."</p>\n" 
    unless $$VARS{ wuhead } =~ /^$legacycheck$/ || $query -> param( 'replaceoldheader' ) ;

  $legacycheck = '^$|(l:kill)?,?c:vote,c:cfull(,\w:' . join( ')?(,\w:' , @footeroptions ) . ',?)?' ;
  my $legacyfoot = '';
  $legacyfoot = '<p>'.$query->checkbox(-name=>'replaceoldfooter',
    -label=>'Overwrite all existing footer settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)')."</p>\n"
    unless $$VARS{ wufoot } =~ /^$legacycheck$/ || $query -> param( 'replaceoldfooter' );

  if(defined($query->param('change_stuff')))
  {
    $$VARS{ wuhead } = 'c:type,c:author,c:audio,c:length,c:hits,r:dtcreate' unless $legacyhead ;
    $$VARS{ wuhead } =~ s/,$// ;

    foreach my $headeroption ( @headeroptions )
    {
      if($query->param('wuhead_'.$headeroption))
      {
        $$VARS{ wuhead } .= ",c:$headeroption," unless $$VARS{ wuhead } =~ /\w:$headeroption/ ;
      } else {
        $$VARS{ wuhead } =~ s/,?\w:$headeroption//g ;
      }
    }

    $$VARS{ wufoot }='l:kill,c:vote,c:cfull,c:sendmsg,c:addto,r:social' unless $legacyfoot ;
    $$VARS{ wufoot } =~ s/,$// ;
    foreach my $footeroption ( @footeroptions )
    {
      if($query->param('wufoot_'.$footeroption))
      {
        $$VARS{ wufoot } .= ",c:$footeroption" unless $$VARS{ wufoot } =~ /\w:$footeroption/ ;
      } else {
        $$VARS{ wufoot } =~ s/,?\w:$footeroption//g ;
      }
    }

    if ( $query -> param( 'nokillpopup' ) )
    {
      $$VARS{ nokillpopup } = 4 ;
    } else {
      delete $$VARS{ nokillpopup }
    }
  }

  $str .= "<fieldset><legend>Writeup Headers</legend>\n";
  $str .= htmlcode('varcheckboxinverse', 'info_authorsince_off','Show how long ago the author was here');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_audio',
    -checked=>( ($$VARS{'wuhead'}=~'audio') ? 1 : 0 ) ,
    -label=>'Show links to any audio files');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_length',
    -checked=>( ($$VARS{'wuhead'}=~'length') ? 1 : 0 ) ,
    -label=>'Show approximate word count of writeup');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_hits',
    -checked=>( ($$VARS{'wuhead'}=~'hits' || $$VARS{'wuhead'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show a hit counter for each writeup');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_dtcreate',
    -checked=>( ($$VARS{'wuhead'}=~'dtcreate' || $$VARS{'wuhead'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show time of creation');
  $str .= "<br>\n";

  $str .= "$legacyhead</fieldset>";

  $str .= "<fieldset><legend>Writeup Footers</legend>\n";

  if ($$USER{title} =~ /^(?:mauler|riverrun|Wiccanpiper|DonJaime)$/ and isGod($USER))
  {
    # only gods can disable pop-up: they get the missing tools in Master Control
    # as of 2011-07-15 only three gods are using it. Let's lose it gradually...
    $str .= $query->checkbox(-name=>'nokillpopup',
      -checked=>( $$VARS{ nokillpopup } == 4 ) ,
      -label=> 'Admin tools always visible, no pop-up' )
      .'<br>';
  }

  $str .= $query->checkbox(-name=>'wufoot_sendmsg',
    -checked=>( ($$VARS{'wufoot'}=~'sendmsg' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show a box to send messages to the author');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wufoot_addto',
   -checked=>( ($$VARS{'wufoot'}=~'addto' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
   -label=>'Show a tool to add the writeup to your bookmarks, a usergroup page or a category');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wufoot_social',
    -checked=>( ($$VARS{'wufoot'}=~'social' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show social bookmarking buttons');
  $str .= "<br>\n";

  if($$VARS{nosocialbookmarking})
  {
    $str .= "<small>To see social bookmarking buttons on other people's writeups you must enable them for yours<br>\n";

    $str .= htmlcode('varcheckboxinverse','nosocialbookmarking','Enable social bookmarking buttons on my writeups')."</small><br>\n"
  }

  $str .= "$legacyfoot</fieldset>";

  $str .= $query->hidden(-name=>'change_stuff');

  $str .= qq|<p><small><strong>[Old Writeup Settings]</strong> provides more control over writeup headers and footers, but the interface is rather complicated.</small></p>|;
  $str .= qq|<fieldset><legend>Homenodes</legend>|;

  $str .= htmlcode("varcheckbox","hidemsgme","I am anti-social.");
  $str .= qq|(So don't display the user /msg box in users' homenodes.)|;
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidemsgyou",'No one talks to me either, so on homenodes, hide the "/msgs from me" link to [Message Inbox]');
  $str .= qq|<br>|;
  
  $str .= htmlcode("varcheckbox","hidevotedata","Not only that, but I'm careless with my votes and C!s (so don't show them on my homenode)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidehomenodeUG","I'm a loner, Dottie, a rebel. (Don't list my usergroups on my homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidehomenodeUC","I'm a secret librarian. (Don't list my categories on my homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","showrecentwucount","Let the world know, I'm a fervent noder, and I love it! (show recent writeup count in homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","hidelastnoded","Link to user's most recently created writeup on their homenode");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Other display options</legend>|;
  $str .= htmlcode("varcheckboxinverse","hideauthore2node","Show who created a writeup page title (a.k.a. e2node)");
  $str .= qq|<br>|;

  $$VARS{ repThreshold } ||= '0' if exists( $$VARS{ repThreshold } ) ; # ecore stores 0 as ''
  if ( $query -> param( 'sexisgood' ) )
  {
    $query -> param( 'activateThreshold' , 1 ) if $query->param('repThreshold') ne '' and $$VARS{repThreshold} eq 'none' ;
    unless ( $query -> param( 'activateThreshold' ) )
    {
      $$VARS{repThreshold} = 'none';
    } else {
      $$VARS{repThreshold} = $query->param('repThreshold');
      unless ( $$VARS{repThreshold} =~ /\d+|none/ )
      {
        delete $$VARS{repThreshold};
      } else {
        $$VARS{repThreshold} = int $$VARS{repThreshold};
	if ( $query->param('repThreshold') > 50 )
        {
          $query->param( 'repThreshold' , 50 );
          $str.="<small>Maximum threshold is 50.</small><br>";
        }
      }
    }
  }

  $query -> param( 'repThreshold' , '' ) if $$VARS{repThreshold} eq 'none';

  $str .= $query -> checkbox( -name=>'activateThreshold' , -value => 1 ,
    -checked=>( $$VARS{repThreshold} eq 'none' ? 0 : 1 ) , -force => 1 ,
    -label=>'Hide low-reputation writeups in New Writeups and e2nodes.' ) ;

  $str .= ' <label>Reputation threshold: ';
  $str .= $query-> textfield( 'repThreshold' , $$VARS{repThreshold} , 3 , 3 );
  $str .= "</label> (default is ".$Everything::CONF->writeuplowrepthreshold.")";

  $str .= qq|<br>|;
  $str .= htmlcode("varcheckbox","noSoftLinks","Hide softlinks");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Information</h2>|;
  $str .= qq|<fieldset><legend>Writeup maintenance</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_notify_kill","Tell me when my writeups are deleted");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_editnotification","Tell me when my writeups get edited by [e2 staff|an editor or administrator]");
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Writeup response</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_coolnotification",'Tell me when my writeups get [C!]ed ("cooled")');
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_likeitnotification","Tell me when Guest Users like my writeups");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_bookmarknotification","Tell me when my writeups get bookmarked on E2");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_bookmarkinformer","Tell others when I bookmark a writeup on E2");
  $str .= htmlcode("varcheckbox","anonymous_bookmark","but do it anonymously");
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Social bookmarking</legend>|;

  $str .= htmlcode("varcheckboxinverse","nosocialbookmarking","Allow others to see social bookmarking buttons on my writeups");
  $str .= qq|<small>Unchecking this will also hide the social bookmarking buttons on other people's writeups.</small><br>|;

  $str .= htmlcode("varcheckboxinverse","no_socialbookmarknotification","Tell me when my writeups get bookmarked on a social bookmarking site");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_socialbookmarkinformer","Tell others when I bookmark a writeup on a social bookmarking site");
  $str .= qq|</p></fieldset>|;

  $str .= qq|<fieldset><legend>Other information</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_discussionreplynotify","Tell me when someone replies to my usergroup discussion posts");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidelastseen","Don't tell anyone when I was last here");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Messages</h2>|;
  $str .= qq|<fieldset><legend>Message Inbox</legend>|;

  $str .= htmlcode("varcheckbox","sortmyinbox","Sort my messages in message inbox");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","mitextarea","Larger text box in Message Inbox");
  $str .= qq|<br></fieldset>|;

  $str .= qq|<fieldset><legend>Usergroup messages</legend>|;
  $str .= htmlcode("varcheckbox","getofflinemsgs","Get online-only messages, even while offline.");
  $str .= '([online only /msg|explanation])';
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Miscellaneous</h2>|;
  $str .= qq|<fieldset><legend>Chatterbox</legend>|;

  $str .= htmlcode("varcheckboxinverse","noTypoCheck","Check for chatterbox command typos");
  $str .= qq|&ndash; /mgs etc.(when enabled, some messages that aren't typos may be flagged as such, although this will protect you against most real typos)<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Nodeshells</legend>|;

  $str .= htmlcode("varcheckbox","hidenodeshells","Hide nodeshells in search results and softlink tables");
  $str .= qq|<br><small>A nodeshell is a page on Everything2 with a title but no content</small>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>GP system</legend>|;
  $str .= htmlcode("varcheckbox","GPoptout","Opt me out of the GP System.");
  $str .= qq|<br>|;
  $str .= qq|<small>[GP] is a points reward system. You get points for doing good stuff and can use them to buy fun stuff.</small>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Little-needed</legend>|;

  $str .= htmlcode("varcheckbox","defaultpostwriteup","Publish immediately by default.");
  $str .= qq|<br>|;

  $str .= qq|<small>(Some older users may appreciate having 'publish immediately' initially selected instead 'post as draft'.)</small><br>|;

  $str .= htmlcode("varcheckbox","noquickvote","Disable quick functions (a.k.a. AJAX).");
  $str .= qq|<br>|;

  $str .= qq|<small>(Voting, cooling, chatting, etc will all require complete pageloads. You probably don't want this.)</small><br>|;

  $str .= htmlcode("varcheckbox","nonodeletcollapser","Disable nodelet collapser");
  $str .= qq|<br>|;
  $str .= qq|<small>(clicking on a nodelet title will not hide its content).</small><br>|;

  $str .= htmlcode("varcheckbox","HideNewWriteups","Hide your new writeups by default");
  $str .= qq|<br>|;
  $str .= "<small>(note: some writeups, such as [Everything Daylogs|day log]s and maintenance-related writeups,always default to a hidden creation)</small><br>";

  $str .= htmlcode("varcheckbox","nullvote","Show null vote button");
  $str .= qq|<br><small>Some old browsers needed at least one radio-button to be selected</small></fieldset>|;

  $str .= qq|<h2>Unsupported options</h2>|;
  $str .= qq|<fieldset><legend>Experimental/In development</legend>|;
  $str .= qq|<p><small>The time zone and other settings here do not currently affect the display of all times on the site.</small><br>|;

  $str .= htmlcode("varcheckbox","localTimeUse","Use my time zone offset");

  #daylight saving time messes things up; cheap way is to have a separate checkbox for daylight saving time
  my %specialNames = (
    '-12:00'=>'International date line West',
    '-11:00'=>'Samoa',
    '-10:00'=>'Hawaii',
    '-9:00'=>'Alaska',
    '-8:00'=>'Pacific (Los Angeles/Vancouver)/Baja California',
    '-7:00'=>'Mountain (Calgary/Denver/Salt Lake City)/Chihuahua/La Paz',
    '-6:00'=>'Central (Winnipeg/Chicago/New Orleans)/Central America',
    '-5:00'=>'Eastern (New York City/Atlanta/Miami)/Bogota/Lima/Quito',
    '-4:30'=>'Caracas',
    '-4:00'=>'Atlantic (Halifax)/Asuncion/Santiago/Georgetown/San Juan',
    '-3:30'=>'Newfoundland',
    '-3:00'=>'Greenland/Rio de Janeiro/Brasilia/Buenos Aires/Montevideo',
    '-1:00'=>'Azores/Cabo Verde',
    '0:00'=>'UTC server time (Lisbon/London/Dublin/Reykjavik/Monrovia)',
    '1:00'=>'Central Europe (Madrid/Amsterdam/Paris/Berlin/Prague)',
    '2:00'=>'Eastern Europe/Jerusalem/Istanbul/Cairo/Cape Town',
    '3:00'=>'Moscow/Baghdad/Nairobi',
    '3:30'=>'Tehran',
    '4:00'=>'Caucasus (Tblisi/Yerevan/Baku)/Abu Dhabi/Port Louis',
    '4:30'=>'Kabul',
    '5:00'=>'Ekaterinburg/Islamabad/Tashkent',
    '5:30'=>'Chennai/Kolkata/Mumbai/Sri Jayawardenepura',
    '6:00'=>'Astana/Dhaka/Novosibirsk',
    '6:30'=>'Yangoon (Rangoon)',
    '7:00'=>'Bangkok/Hanoi/Jakarta/Krasnoyarsk',
    '8:00'=>'Beijing/Hong Kong/Singapore/Urumqi/Irkutsk/Perth/Ulaanbataar',
    '9:00'=>'Tokyo/Seoul/Yakutsk',
    '9:30'=>'Adelaide/Darwin',
    '10:00'=>'Guam/Sydney/Melbourne/Brisbane/Vladivostok',
    '11:00'=>'Magadan/Solomon Islands/New Caledonia',
    '12:00'=>'Auckland/Wellington/Fiji',
    '13:00'=>'Nuku\'alofa',
  );

  my $params='';
  my $t= -43200; # 12 * 3600: time() uses seconds
  my $minutes = '00';
  my $plus ;
  for(my $hours=-12;$hours<=13;++$hours)
  {
    my $n = ( $hours % 12 ? 2 : ( $hours ? 1 : 3 ) );
    $plus = '-' unless $hours ;
    for (my $i=$n; $i ; $i--)
    {
      my $zone = "$hours:$minutes" ;
      $params .= ",$t,$plus$zone".($specialNames{$zone} ? " - $specialNames{$zone}" :'');
      $minutes = $minutes eq '00' ? '30' : '00' ;
      $t += 1800 ;
      $plus = '+' unless $hours ;
    }
  }
  $params =~ s/\b(\d):/0$1:/g ;
  #Y2k bug:
  #	60*60*24*365*100=3153600000=100 years ago, 365 days/year
  #	60*60*24*25=2160000=25 extra leap days; adjustment to 26: Feb 29, 2004
  #week in future:
  #	60*60*24*7=604800=week

  $params=',-3155760000,Y2k bug'.$params.',604800,I live for the future';

  $str .= htmlcode('varsComboBox', 'localTimeOffset,0'.$params);
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","localTimeDST","I am currently in daylight saving time");
  $str .= qq|(so add an an hour to my normal offset)<br>|;

  $str .= htmlcode("varcheckbox","localTime12hr","I am from a backwards country that uses a 12 hour clock");
  $str .= qq|(show AM/PM instead of 24-hour format)|;

  $str .= qq|</p></fieldset>|;

  $str .= htmlcode("closeform");
  return $str;
}

sub alphabetizer
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Go ahead -- one entry per line:</p>|;
  $str .= htmlcode("openform");

  $str .= qq|<p><!-- N-Wing added options 2005-12-12 -->|;

  $str .= qq|separator: |;
  $str .= htmlcode("varsComboBox","alphabetizer_sep",0,0,"none (default)",1,"<br>",2,"<li> (use in UL or OL)");
  $str .= qq|<br />|;

  $str .= qq|sort: |;
  $str .= htmlcode("varcheckbox","alphabetizer_sortorder","reverse");
  $str .= htmlcode("varcheckboxinverse","alphabetizer_case","ignore case (default yes)");
  $str .= qq|<br />|;

  $str .= htmlcode("varcheckbox","alphabetizer_format","make everything an E2 link");

  $str .= qq|</p><p>|;

  $str .= $query->textarea('alpha', '', 20,60);
  $str .= qq|</p>|;

  $str .= htmlcode("closeform");

  my $list = $query->param('alpha');
  return $str unless $list;

  my $outputstr = '';
  my $leOpen = '';
  my $leClose = '';
  my $s = $VARS->{'alphabetizer_sep'};
  if($s==1)
  {
    $leClose = '&lt;br&gt;'
  } elsif($s==2) {
    $leOpen = '&lt;li&gt;';
    $leClose = '&lt;/li&gt;';
  } else {
    #no formatting
  }

  my @entries = split "\n", $list;

  foreach(@entries)
  {
    s/^\s*(.*?)\s*$/$1/;

    # Put articles at the end so they don't screw up
    # the sort.
    $_ =~ s/^(An?) (.*)$/$2, $1/i;
    $_ =~ s/^(The) (.*)$/$2, $1/i;
  }

  if($VARS->{'alphabetizer_case'})
  {
    @entries = sort @entries;
  } else {
    @entries = sort {lc($a) cmp lc($b)} @entries;
  }

  @entries = reverse @entries if $VARS->{'alphabetizer_sortorder'};

  foreach(@entries)
  {
    next unless length($_);
    $_ =~ s/^(.*), (An?)/$2 $1/i;
    $_ =~ s/^(.*), (The)/$2 $1/i;

    if($VARS->{'alphabetizer_format'})
    {
      #put brackets around the string.
      $_ = '['.$_.']';
    }
  }

  foreach (@entries)
  {
    next unless length($_);

    $outputstr .= $leOpen . encodeHTML($_,1) . $leClose . "\n";
  }

  return qq|$str<pre>$outputstr</pre></p>|;
}

sub ask_everything__do_i_have_the_swine_flu_
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>You walk up to the Everything Oracle, insert your coin, and ask the question that's most on your mind: DO I HAVE [SWINE FLU]???</p>|;
  $str .= qq|<br>The answer instantly flashes on the screen:<br><br><p align=center>|;

  my @flu = (
    "No.",
    "Yes.",
    "Maybe.",
    "I'm afraid that is classified information.",
    "Does your mother know you're here?",
    "Who wants to know?",
    "No.",
    "Please try again.",
    "I could tell you but then I'd have to kill you. If the Swine Flu doesn't do it first.",
    "No. You're probably Jewish and not allowed to have Swine Flu.",
    "You... INSERT ANOTHER COIN",
    "No. But for aboot tree-fiddy I get you some.",
    "Would you rather have the answer that's behind door number three?",
    "Not yet",
    "No. You don't deserve it.",
    "Yes. You've earned it.",
    "Hast thou eaten of the tree, whereof I commanded thee that thou shouldest not eat? Damn right you have the Swine Flu!",
    "I'm sorry, Dave. I cannot allow this.",
    "Yes. You got it from kissing Al Gore.",
    "Yes. You got it from kissing Janet Reno.",
    "Yes. A tall, dark stranger gave it to you.",
    "Yes. It's part of an evil plot by the E2 gods.",
    "No.",
    "Why does it always have to be about you?",
    "No. Nice shoes!",
    "Yes. And the horse you rode in on",
    "No. You have Avian Flu. Get a clue and know the difference!",
    "No. Your biology is too alien to be infected.",
    "No. You may be a swine but you're not that kind of swine.",
    "No. Just no.",
    "No. Have you made your will yet?",
    "No. But, if you ask nicely, you can have mine.",
    "What, you didn't get yours yet? Here, have some.",
    "You sick puppy, you...",
    "Who's asking? Oh, it's you, ignorant as usual.",
    "I'm not sure. Let's play doctor and find out.",
    "What do you mean, SWINE FLU? Omigod, you were with that floozy again!! What did you catch this time? That's it! I'm taking the kids and am going to my mother's!",
    "Yes. No. Yes. No. Oh, whatever.",
    "Yes. YES. <b>OH GOD YES!</b>",
    "Maybe. What's in it for me?",
    "I know but I'm not telling.",
    "ACCESS DENIED",
    "Do I look like a doctor?",
    "My sources say no",
    "Outlook not so good",
    "Signs point to yes",
    "I see dead people.",
    "Wouldn't you like to know?",
    "No. Swine Flu is not an STD.",
    "No. I'd do something about that rash, though.",
    "No. You're not smart enough to get it.",
    "No.",
    "Yes. Now go away.",
    "42",
    "YES. OH YES! Thank you so much for asking!",
    "Whaddaya mean, do you have Swine Flu? If you don't know, who does?",
    "What do I care if you have Swine Flu?",
    "GUARDS!!!",
    "No.",
    "Yes. No. What was the question again?",
    "No. Can I have your stuff when you die?",
    "GET AWAY FROM ME!!!"
  );

  $str .= "<b><font size='+1'>".$flu[int(rand(@flu))]."</font></b>";
  $str .= qq|</p>|;
  return $str;
}

sub available_rooms
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @stuff = ("Yeah, yeah, get a room...", "I'll take door number three...", "Hey, that's a llama back there!", "Three doors, down, on your right, just past [Political Asylum]", "They can't ALL be locked!?", "Why be so stuffed up in a room? [Go outside]!");

  my $str ="<p align=\"center\">".($stuff[rand(@stuff)])."</p><br><br>"."<p align=\"right\">..or you could ".linkNode(getNode("go outside", "superdocnolinks"))."</p><br><br>";

  my $csr = $DB->sqlSelectMany("node_id, title", "node", "type_nodetype=".getId(getType("room")));

  my $rooms = {};

  while(my $ROW = $csr->fetchrow_hashref())
  {
    $$rooms{lc($$ROW{title})} = $$ROW{node_id};
  }

  $str.="<ul>";

  foreach(sort(keys %$rooms))
  {
    $str.="<li>".linkNode(getNodeById($$rooms{$_}));
  }

  $str.="</ul>";
  return $str;
}

sub back_up_my_vars
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'You must be a logged-in user to use this tool.' if $APP->isGuest($USER);

  my $isAdmin = $APP->isAdmin($USER);

  my $getRecentBackup = sub {
    my $forUser = shift;

    return if !$forUser;
  
    return $DB->sqlSelect(
      "setting_backup_date, vars"
      , "settings_backup"
      , "setting_id = $$forUser{user_id}"
      , "ORDER BY setting_backup_date DESC
         LIMIT 1");
  };

  my $backupVarsFor = sub {
    my ($forUser) = shift;

    return if !$forUser;

    return $DB->sqlInsert(
      "settings_backup"
      , {
         -setting_backup_date => "now()"
        , -setting_id => $$forUser{user_id}
        , vars => $$forUser{vars}
      }
    );
  };

  my $str = "";

  my $backupUser = $USER;
  if ($isAdmin && defined $query->param('backupname'))
  {
    my $backupName = $query->param('backupname');
    my $tryUser = getNode($backupName, 'user');
    $backupUser = $tryUser if $tryUser;
  }


  $str .= htmlcode('openform', 'backupvarsform', 'GET') . "<fieldset><legend>Back Up</legend>";

  if ($query->param('backupvars'))
  {
    &$backupVarsFor($backupUser);
    if ($$backupUser{title} eq $$USER{title})
    {
       $str .= "<p><strong>Backed up your vars.</strong></p>";
    } else {
       $str .= "<p><strong>Backed up $$backupUser{title}'s vars.</strong></p>";
    }
  }

  if ($isAdmin)
  {
    $str .= $query->textfield("backupname", $$backupUser{title}, 80);
  }

  $str .= $query->submit( -name => 'backupvars', -value => "Back me up now"). "</fieldset>";
  $str .= $query->end_form();

  return $str if !$isAdmin;

  $str .= htmlcode('openform', 'restorevarsform', 'GET');
  $str .= "<fieldset><legend>Restore VARS</legend>";

  if (my $restoreName = $query->param('restorename'))
  {
    my ($isThisUser, $forUser);
    $str .= "<p>Trying to restore VARs for " . encodeHTML($restoreName) . ".<br>";

    if ($restoreName eq $$USER{title})
    {
      $isThisUser = 1;
      $forUser = $USER;
    } else {

      $forUser = getNode($restoreName, 'user');

    }

    if ($forUser)
    {
      my ($timeOfBackup, $backedupVars) = &$getRecentBackup($forUser);

      if ($timeOfBackup eq '')
      {
        $str .= "<strong>No backup for that user.</strong></p>";
      } else {
        $str .= "Restoring most recent backup for $$forUser{title} from $timeOfBackup.<br>";
        $str .= "Backing up current VARS just in case...<br>";
        &$backupVarsFor($forUser);

        if ($isThisUser)
        {
          # Write string of vars to user object, then use built in function to
          #  extract this into a hash we assigned to $VARS
          $$USER{vars} = $backedupVars;
          $VARS = getVars($USER);
          $str .= "Restored your VARS.  This will fully reflect on your next pageload.";

        } else {

          my $superuser = -1;
          $$forUser{vars} = $backedupVars;
          updateNode($forUser, $superuser);
          $str .= "Restored VARS.  Should take effect immediately.";
        
        }

      }

    } else {

      $str .= "<strong>No user by that name.</strong>";

    }

    $str .= '</p>';

  }

  $str .= $query->textfield("restorename", $$USER{title}, 80);
  $str .= $query->submit( -name => 'restorevars', -value => "Restore user's VARS");
  $str .= "</fieldset>";
  $str .= $query->end_form();

  my ($timeOfBackup, $backedupVars) = &$getRecentBackup($backupUser);

  my $backupInfo = "";

  my $whoBackedUp = "Your";

  if ($$backupUser{title} ne $$USER{title})
  {
    $whoBackedUp = "$$backupUser{title}'s";
  }

  $backupInfo .= "<p>$whoBackedUp most recently backed up (at time $timeOfBackup) vars are:</p>";
  $backupInfo .= "<pre>$backedupVars</pre>";

  return $backupInfo . $str;
}

sub bad_spellings_listing
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>If you have the option enabled to show <strong>common bad spellings</strong> in your writeups, common bad spellings will be flagged and displayed you are looking at your writeup by itself (as opposed to the e2node, which may contain other noders' writeups).</p>|;
  $str .= qq|<p>This option can be toggled at [Settings[Superdoc]] in the Writeup Hints section. You currently have it |;
  $str .= $VARS->{nohintSpelling} ? 'disabled, which is not recommended' : 'enabled, the recommended setting';
  $str .= qq|</p><p>|;

  my $spellInfo = getNode('bad spellings en-US','setting');
  return $str.'<strong>Error</strong>: unable to get spelling setting.' unless defined $spellInfo;

  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  if($isRoot)
  {
    $str .= '<p>(Site administrators can edit this setting at '.linkNode($spellInfo,0,{lastnode_id=>0}).'.)</p><p>
';
  }

  $spellInfo = getVars($spellInfo);
  return $str.'<strong>Error</strong>: unable to get spelling information.' unless defined $spellInfo;

  #table header
  $str .= qq|Spelling errors and corrections:<table border="1" cellpadding="2" cellspacing="0"><tr><th>invalid</th><th>correction</th></tr>|;

  #table body - wrong spellings to correct spellings
  my $s="";
  my $numShown = 0;
  foreach(sort(keys(%$spellInfo)))
  {
    next if substr($_,0,1) eq '_';
    next if $_ eq 'nwing';
    ++$numShown;
    $s = $_;
    $s =~ tr/_/ /;
    $str .= '<tr><td>'.$s.'</td><td>'.$$spellInfo{$_}.'</td></tr>';
  }

  #table footer
  $str .= '</table>';

  $str .= '('.$numShown.' entries';
  $str .= ' shown, '.scalar(keys(%$spellInfo)).' total' if $isCE;
  $str .= ')';

  $str .= qq|</p>|;
  return $str;
}

sub bestow_easter_eggs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  return 'Who do you think you are? The Easter Bunny?' unless $APP->isAdmin($USER);

  my @params = $query->param;
  my $str = '';

  my (@users, @thenodes);
  foreach (@params)
  {
    if(/^eggUser(\d+)$/)
    {
      $users[$1] = $query->param($_);
    }
  }

  for(my $count=0; $count < @users; $count++)
  {
    next unless $users[$count];

    my ($U) = getNode ($users[$count], 'user');
    if (not $U)
    {
      $str.="couldn't find user $users[$count]<br />";
      next;
    }

    # Send an automated notification.
    my $failMessage = htmlcode('sendPrivateMessage',{
      'recipient_id'=>getId($U),
      'message'=>'Far out! Somebody has given you an [easter egg].',
      'author'=>'Cool Man Eddie',
      });

    $str .= "User $$U{title} was given one easter egg";
  
    my $v = getVars($U);
    if (!exists($$v{easter_eggs}))
    {
      $$v{easter_eggs} = 1;
    } else {
      $$v{easter_eggs} += 1;
    }
   
    setVars($U, $v);
    $str .= "<br />\n";
  }

  # Build the table rows for inputting user names
  my $count = 5;
  $str.=htmlcode('openform');
  $str.='<table border="1">';
  $str.="\t<tr><th>Egg these users</th></tr> ";

  for (my $i = 0; $i < $count; $i++)
  {
    $query->param("eggUser$i", '');
    $str.="\n\t<tr><td>";
    $str.=$query->textfield("eggUser$i", '', 40, 80);
    $str.="</td>";
  }

  $str.='</table>';

  $str.=htmlcode('closeform');

  if ($query->param("Give yourself an egg you greedy bastard"))
  {
    if (!exists($$VARS{easter_eggs}))
    {
      $$VARS{easter_eggs} = 1;
    } else {
      $$VARS{easter_eggs} += 1;
    }
  }

  $str.=htmlcode('openform');
  $str.=$query->submit('Give yourself an egg you greedy bastard');
  $str.=$query->end_form;

  return $str;
}

sub between_the_cracks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isGuest = $APP->isGuest($USER);
  return "<p>Undifferentiated from the masses of the streets, you fall between the cracks yourself.</p>" if $isGuest;

  my $rowCtr = 0;

  my ($title, $queryText, $rows);
  my $count = 1000;
  my $maxVotes = int($query->param("mv"));
  my ($minRep, $repRestriction, $repStr) = (undef, '', '');
  my $resultCtr = 50;

  if ($maxVotes <= 0)
  {
    $maxVotes = 5;
  }

  if (defined $query->param("mr") && $query->param("mr") ne "")
  {
    $minRep = int($query->param("mr"));
    if ($minRep > 5 || abs($minRep) > ($maxVotes - 2))
    {
      $minRep = undef;
    }
  
    if (defined $minRep)
    {
      $repRestriction = "AND reputation >= $minRep";
      $repStr = " and a reputation of $minRep or greater";
    }
  }

  my $str = qq|<p>These nodes have fallen between the cracks, and seem to have gone unnoticed. This page lists <em>up to</em> $resultCtr writeups that you haven't voted on that have fewer than $maxVotes total vote(s)$repStr on E2. Since they have been neglected until now, why don\'t you visit them and click that vote button?</p>|;
  $str .= qq|<form method="get"><div>|;
  $str .= qq|<input type="hidden" name="node_id" value="|.getId($NODE).qq|" />|;
  $str .= qq|<b>Display writeups with |;

  my @mvChoices = ();

  for(my $i=1;$i<=10;$i++)
  {
    push @mvChoices, $i
  }

  $str .= $query->popup_menu('mv', \@mvChoices, $maxVotes);
  $str .= ' (or fewer) votes and ';

  my %mrLabels = ();
  my @mrValues = ();

  for(my $i=-3;$i<=3;$i++)
  {
    $mrLabels{$i} = $i;
    push @mrValues, $i;
  }

  $mrLabels{''} = 'no restriction';
  push @mrValues, '';

  $str .= $query->popup_menu(-name => 'mr',
    -labels => \%mrLabels,
    -default => $minRep,
    -values => \@mrValues);

  $str .= ' (or greater) rep.';

  $str .= qq|</b><input type="submit" value="Go" /></div></form>|;
  $str .= qq|<table width="100%"><tr><th>#</th><th>Writeup</th><th>Author</th>|;
  $str .= qq|<th>Total Votes</th><th>Create Time</th></tr>|;

  $queryText = qq|SELECT title, author_user, createtime, writeup_id, totalvotes
    FROM writeup
    JOIN node
      ON writeup.writeup_id = node.node_id
    LEFT OUTER JOIN vote
      ON vote.vote_id = node.node_id AND vote.voter_user = $$USER{user_id}
    WHERE
      node.totalvotes <= $maxVotes
      $repRestriction
      AND node.author_user <> $$USER{user_id}
      AND vote.voter_user IS NULL
      AND wrtype_writeuptype <> 177599
    ORDER BY writeup.writeup_id
    LIMIT $count|;

  $rows = $DB->{dbh}->prepare($queryText);
  $rows->execute() or return $rows->errstr;

  while(my $wu = $rows->fetchrow_hashref)
  {
    $title = $$wu{title};
    if($title =~ /^(.*?) \([\w-]+\)$/) { $title = $1; }
    $title =~ s/\s/_/g;

    if ( !$APP->isUnvotable($$wu{writeup_id}) )
    {
      $rowCtr++;
      if ($rowCtr % 2 == 0)
      {
        $str .= '<tr class="evenrow">';
      }else{
        $str .= '<tr class="oddrow">';
      }
      $str .= '<td style="text-align:center;padding:0 5px">'.$rowCtr.'</td>
         <td>'.linkNode($$wu{writeup_id}, '', {lastnode_id=>0}).'</td>
         <td>'.linkNode($$wu{author_user}, '', {lastnode_id=>0}).'</td>
         <td style="text-align:center">'.$$wu{totalvotes}.'</td>
         <td style="text-align:right">'.$$wu{createtime}.'</td>
         </tr>';
    }
    last if ($rowCtr >= $resultCtr);
  }

  if ($rowCtr == 0)
  {
    $str .= '<tr><td colspan="3"><em>You have voted on all '.$count.' writeups with the lowest number of votes.</em></td></tr>';
  }

  $str .= '</table><p style="text-align:right">Bugs to [in10se]</p>';

  return $str;
}

sub blind_voting_booth
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $poweruser = $APP->isEditor($USER);

  my $wu = undef;
  my $hasvoted = 0;

  my $str = 'Welcome to the blind voting booth.  You can give anonymous feedback without knowing who wrote a writeup here, if you so choose.<br><br>';


  if(!($query->param('op') eq 'vote'))
  {
    return qq|You're done for today| if($$USER{votesleft} == 0);

    my $wucount = 0;
    while(!$wu && $wucount < 30)
    {
 
      my $limit = $DB->sqlSelect("max(writeup_id)", "writeup");
      my $min = $DB->sqlSelect("min(writeup_id)", "writeup");
      my $rnd = int(rand($limit-$min));

      $rnd+= $min;

      my $maybewu = $DB->sqlSelect("writeup_id", "writeup", "writeup_id=$rnd");

  
      if($maybewu)
      {
        my $tempref = getNodeById($maybewu);

        if($$tempref{wrtype_writeuptype} != 177599  && $$tempref{author_user} != $$USER{user_id})
        {
          $wu = $maybewu if(!$APP->hasVoted($tempref, $USER));
        }
      }

      $wucount++;
    }

  } else {
    my $wutemp = getNodeById($query->param('votedon'));

    return linkNode($NODE, 'Try Again') unless($wutemp);
    return linkNode($NODE, 'Try Again') if(!$APP->hasVoted($wutemp, $USER));

    $wu = $query->param('votedon');
    $hasvoted = 1;

  }

  my $rndnode = getNodeById($wu);
  my $nodeauthor = getNodeById($$rndnode{author_user});

  $str.=htmlcode('votehead');
  $str.='(<b>'.$$rndnode{title}.'</b>) by ';
  if($hasvoted == 1)
  {
    $str.=linkNode(getNode($$nodeauthor{title}, 'user'), $$nodeauthor{title}).' - ('.linkNode(getNodeById($$rndnode{parent_e2node}), 'full node').')';
  } else {
    $str.='? - ('.linkNode(getNodeById($$rndnode{parent_e2node}), 'full node').')';
  }
  
  $str.='<br>';

  if($hasvoted == 0)
  {
    $str.='<input type="hidden" name="votedon" value="'.$$rndnode{node_id}.'"><input type="radio" name="vote__'.$$rndnode{node_id}.'" value="1"> +<input type="radio" name="vote__'.$$rndnode{node_id}.'" value="-1"> - '.linkNode($NODE, 'pass on this writeup', {garbage=>int(rand(100000))});
  } else {
    $str.='Reputation: '.$$rndnode{reputation};
  }

  $str.='<br><hr><br>';
  $str.=$$rndnode{doctext};

  if($hasvoted == 0)
  {
    $str.='<table border="0" width="100%"><tr><td align="left"><INPUT TYPE="submit" NAME="sexisgreat" VALUE="vote!"></td>';
    if($poweruser)
    {
      $str.= '<td align="right"><INPUT TYPE="submit" NAME="node" VALUE="the killing floor II"></td>';
    }
    
    $str.='</tr></table></form>';
  }

  $str.= '<br><br><hr><br>'.linkNode($NODE, 'Another writeup, please') if($hasvoted && $$USER{votesleft} != 0);

  return $str;
}

sub bounty_hunters_wanted
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<style type="text/css"> .mytable th, .mytable td {border: 1px solid silver;padding: 3px;}</style>|;

  $str .= qq|<p align=center><b>[Everything's Most Wanted] is now automated</b></p>|;

  $str .= "<p>Okay, so [mauler|I] just finished fully automating the [Everything's Most Wanted] feature so that noders can manage bounties they have posted by themselves without having to go through the tedious process of messaging an admin several times. Hopefully this feature should be a lot more useful now. [Everything's Most Wanted|Check it out!]</p>";

  $str .= "<p>The five most recently requested nodes are automatically listed below. If you fill one of these, please message the requesting noder to claim your prize. Please see [Everything's Most Wanted|the main list] for full details on conditions and rewards.</p>";

  $str .= qq|<p>&nbsp;</p>|;

  $str .= qq|<table>|;

  $str.="<p><table class='mytable' align=center><tr><th>Requesting Sheriff</th><th>Outlaw Nodeshell</th><th>GP Reward (if any)</th></tr>";

  my $REQ = getVars(getNode('bounty order','setting'));
  my $OUT = getVars(getNode('outlaws', 'setting'));
  my $REW = getVars(getNode('bounties', 'setting'));
  my $HIGH = getVars(getNode('bounty number', 'setting'));
  my $MAX = 5;

  my $bountyTot = $$HIGH{1};
  my $numberShown = 0;
  my $outlawStr = "";
  my $requester = undef;
  my $reward = undef;

  for(my $i = $bountyTot; $numberShown < $MAX; $i--)
  {

    if (exists $$REQ{$i})
    {
      $numberShown++;
      $requester = $$REQ{$i};
      $outlawStr = $$OUT{$requester};
      $reward = $$REW{$requester};
      $str.="<tr><TD>[$requester]</TD><TD>$outlawStr</TD><TD>$reward</TD></tr>";
    }
  }

  $str .= "</table><p align=center>([Everything's Most Wanted|see full list])</p><p>&nbsp;</p>";

  return $str;
}

1;