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

sub buffalo_generator
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @verbNouns=('Buffalo', 'buffalo', 'police', 'bream', 'perch', 'char', 'people', 'dice', 'cod', 'smelt', 'pants');
  my @intermediatePunctuation=(',', ';', ',', ':', '...');
  my @finalPunctuation=('.', '!', '?');

  my $str='';
  my $sentence='';

  @verbNouns=('buffalo') if ($query->param('onlybuffalo'));

  while (1)
  {
    $sentence='';
    while (1)
    {
      $sentence.=$verbNouns[int(rand(@verbNouns))];
      last if(rand(1)<0.1);
      $sentence.=$intermediatePunctuation[int(rand(@intermediatePunctuation))] if (rand(1)<0.25);
      $sentence.=" ";
    }
    $sentence=ucfirst($sentence);
    $sentence.=$finalPunctuation[int(rand(@finalPunctuation))].' ';
    $str.=$sentence;
    last if(rand(1)<0.4);
  }

  $str.="<ul>\n\t<li>".linkNode($NODE, "MOAR", {moar => 'more'})."</li>\n";
  $str.="\n\t<li>".linkNode($NODE, "Only buffalo", {onlybuffalo => 'true'})."</li>\n";
  $str.="\n\t<li>".linkNodeTitle("Buffalo Haiku Generator|In haiku form")."</li>\n";
  $str.="\n\t<li>".linkNodeTitle("Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo|...what?")."</li></ul>\n";

  return $str;

}

sub buffalo_haiku_generator
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @verbNouns=('Buffalo', 'buffalo', 'police', 'people', 'bream', 'perch', 'char', 'dice', 'cod', 'smelt', 'pants');
  my @wordLength=(3,3,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1);
  my @intermediatePunctuation=(',', ';', ',', ':', '...');
  my @finalPunctuation=('.', '!', '?');
  my @lineLength=(5,7,5); 
  my $str='';
  my $sentence='';

  @verbNouns=('buffalo') if ($query->param('onlybuffalo'));

  $sentence='<p style="text-align:center">';
  for (my $i=0; $i<3; $i++)
  {
    my $syllables=0;
    while ($syllables<$lineLength[$i])
    {
      my $wordNumber=(rand(@verbNouns));
      if ($syllables+$wordLength[$wordNumber]>$lineLength[$i])
      {
        $wordNumber=(4+rand(@verbNouns-4)); # Pick a one-syllable word.
      }
      $syllables+=$wordLength[$wordNumber];
      $sentence.=$verbNouns[$wordNumber];
      $sentence.=$intermediatePunctuation[int(rand(@intermediatePunctuation))] if (rand(1)<0.1);
      $sentence.=" ";
    }
    $sentence.="<br />";    
  }
  $sentence=ucfirst($sentence);
  $str.=$sentence."</p>";


  $str.="<ul>\n\t<li>".linkNode($NODE, "Furthermore!", {moar => 'further'})."</li>\n";
  $str.="\t<li>".linkNodeTitle("Buffalo Generator|More buffalo, less haiku")."</li>\n";
  $str.="\t<li>".linkNodeTitle("Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo")."</li></ul>\n";

  return $str;
}

sub chatterbox_help_topics
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>The chatterbox help topics are a good way for new users to learn some of the basics of E2.  Simply type "/help TOPIC" in the chatterbox to get an automated message from |;
  $str .= linkNode(getNode('Virgil','user'));
  $str .= qq| about that topic.  Best results will be achieved by searching in lowercase and multi-word topics should use underscores rather_than_spaces.  If you notice errors, or think additional topics should be available, contact [wertperch].</p>|;

  $str .= qq|<p>Examples:|;
  $str .= qq|<br><tt>/help editor</tt>|;
  $str .= qq|<br><tt>/help wheel_of_surprise</tt></p>|;

  $str .= qq|<h3>Currently available help topics</h3>|;
  $str .= qq|<p>(not including aliases for topics listed under multiple titles)</p>|;

  $str .= qq|<ol>|;

  my $helpTopics = getNode('help topics', 'setting');
  my $helpVars = getVars($helpTopics);

  ##########
  # Display the list of help topics
  # Except for the ones that are aliases to other topics.
  # NOTE:  Please standardize any added help topics by keeping the main topic
  #        all lowercase and as intuitive as possible.
  #        less intuitive and upper-case versions should be an alias.

  foreach my $keys (sort(keys(%{$helpVars})))
  {
    $str .= "\n\t<li>/help " . $keys . "</li>" unless ( $$helpVars{$keys} =~ /^\/help .*/ );
  }

  return $str . "\n</ol>\n\n";
}

sub chatterlighter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $nlid = getNode( 'Notifications' , 'nodelet' ) -> { node_id } ;
  $PAGELOAD->{ pagenodelets } = "$nlid," if $$VARS{ nodelets } =~ /\b$nlid\b/ ;
  $PAGELOAD->{ pagenodelets } .= getNode( 'New Writeups' , 'nodelet' ) -> { node_id } ;

  my $str = insertNodelet( getNode( 'Chatterbox', 'nodelet' ) );
  $str .= qq|<span class="instant ajax chatterlight_rooms:updateNodelet:Other+Users"></span>|;
  $str .= qq|<div id="chatterlight_rooms">|;
  $str .= qq|<p><span title="What chatroom you are in">Now talking in: |;
  $str .= linkNode($$USER{in_room}) || "outside";
  $str .= qq|</span> |;
  $str .= htmlcode("changeroom");
  $str .= qq|</div>|;

  return $str;
}

sub clientdev_home
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = qq|<h2>Registered Clients</h2>|;
  $str .= qq|<p>|;
  $str .= "(See [clientdev: Registering a client|here] for more information as to what this is about)<br />";
  $str .= qq|<table border="1" cellpadding="1" cellspacing="0">|;
  $str .= qq|<tr><th>title</th><th>version</th></tr>|;

  my @clientdoc = getNodeWhere ({}, 'e2client', 'title');
  my $v = undef;

  foreach (@clientdoc)
  {
    $v = $_->{'version'};
    $str .=
    '<tr><td>' . linkNode($_) . '</td><td>' .((defined $v) && length($v) ? encodeHTML($v,1) : ''). '<td></tr>';
  }

  $str .= '</table>';

  if($DB->isApproved($USER, $NODE))
  {
    $str.=htmlcode('openform');
    $str.="<input type=\"hidden\" name=\"op\" value=\"new\">\n";
    $str.="<input type=\"hidden\" name=\"type\" value=\"e2client\">\n";
    $str.="<input type=\"hidden\" name=\"displaytype\" value=\"edit\">\n";
    $str.='<h2>Register your client:</h2>';
    $str.=$query->textfield('node', '', 25);
    $str.=htmlcode('closeform');
  }

  $str .= qq|</p>|;

  $str .= qq|<p>Things to (eventually) come:</p>|;
  $str .= qq|<ol><li>make debates work for general groups</li>|;
  $str .= qq|<li>list of people, their programming language, the platform, and the project</li>|;
  $str .= qq|</ol>|;

  $str .= qq|<p>|;
  $str .= htmlcode("linkGroupMessages","N-Wing");
  $str .= qq|</p>|;

  $str .= qq|<p><hr /></p>|;

  my $cd = getNode("clientdev","usergroup");
  if($DB->isApproved($USER, $cd))
  {
    $str .= "<p>\n".htmlcode('weblog',"5,$cd->{node_id}")."\n<p>";
  }

  return $str;
}

sub confirm_password
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $token = $query->param('token');
  my $action = $query->param('action');
  my $expiry = $query->param('expiry');
  my $username = $query->param('user');

  unless($token and $action and $username)
  {
    return qq|<p>To use this page, please click on or copy and paste the link from the email we sent you. </p>|.
      qq|<p>If we didn't send you an email, you don't need this page.</p>|;
  }
  
  return '<p>Invalid action.</p>' unless($action eq 'activate' || $action eq 'reset');

  my $user = getNode($username, 'user');

  if ($expiry && time() > $expiry)
  {
    # make sure unactivated account is gone in case they want to recreate it
    $DB->nukeNode($user, -1, 'no tombstone') if $action eq 'activate'
      && $user && !$user -> {lasttime} && $expiry =~ /$$user{passwd}/;

    return $query->p('This link has expired. But you can '
      .linkNode(getNode($action eq 'reset' ? 'Reset password' : 'Sign up', 'superdoc')
      , 'get a new one').'.');
  }

  return $query->p(
    'The account you are trying to activate does not exist. But you can '
    .linkNode(getNode('Sign up', 'superdoc') , 'create a new one').'.') unless $user;

  return "<p>We're sorry, but we don't accept new users from the IP address you
    used to create this account. Please get in touch with us if you think this
    is a mistake.</p>" if $action eq 'activate' && $user -> {acctlock};

  my $prompt = '';

  if ($query -> param('op') ne 'login')
  {
    # check for locked-user infection...
    my $newVars = getVars($user);
    if ($$newVars{infected})
    {
      # new user infects current user
      $$VARS{infected} = 1 unless $APP -> isGuest($USER);

    }elsif(htmlcode('checkInfected')){
      # current user infects new user
      $$newVars{infected} = 1;
      setVars($user, $newVars);
    }

    $action = 'validate' if $$newVars{infected};

    $prompt = "Please log in with your username and password to $action your account";

  }elsif($USER -> {title} ne $username || $$USER{salt} eq $query -> param('oldsalt')){
    $prompt = 'Password or link invalid. Please try again';
  }

  $query -> delete('passwd');

  return htmlcode('openform')
    .$query->fieldset({style => 'width: 25em; max-width: 100%; margin: 3em auto 0'},
      $query->legend('Log in')
      .$query -> p($prompt.':')
      .$query -> p({style => 'text-align: right'},
        $query -> label('Username:'
        .$query -> textfield(
          -name => 'user'
          , readonly => 'readonly'
          , size => 30
          , maxlength => 240))
          .'<br>'
        .$query -> label('Password:'
        .$query -> password_field('passwd', '', 30, 240))
        .'<br>'
        .$query->checkbox("expires", "", "+10y", 'stay logged in')
        .'<br>'
        .$query -> submit('sockItToMe', $action)
      )
    )
    .$query -> hidden('token')
    .$query -> hidden('action')
    .$query -> hidden('expiry')
    .$query -> hidden('oldsalt', $$USER{salt})
    .$query -> hidden(-name => 'op', value => 'login', force => '1')
    .'</form>' if $prompt;

  return "<p>Password updated. You are logged in.</p>" if $action eq 'reset';

  # send welcome message
  htmlcode('sendPrivateMessage', {
    'author_id' => getId(getNode('Virgil','user')),
    'recipient_id' => $USER -> {node_id},
    'message' => "Welcome to E2! We hope you're enjoying the site. If you haven't already done so,
    We recommend reading both [E2 Quick Start] and [Links on Everything2] before you start writing anything. If you have any questions or need help, feel free to ask any editor (editors have a \$ next to their names in the Other Users list)" });

  return "<p>Your account has been activated and you have been logged in.</p>
    <p>Perhaps you'd like to edit " .linkNode($USER, 'your profile')
    .", or check out the logged-in users' <a href='/'>front page</a>,
    or maybe just read <a href='/?op=randomnode'>something at random</a>.";

}

sub cool_archive
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Welcome to the Cool Archive page -- where you can see the entire|;
  $str .= qq|library of especially worthwhile content in the mess of Everything history.  Enjoy.|;
  $str .= qq|<small>(|;
  $str .= linkNode(getNode('Cool Archive Atom Feed','ticker'),'feed',{lastnode_id=>0});
  $str .= qq|)</small></p>|;

  $str .= qq|<p><strong>NB</strong>: sorting by something other than most recently or oldest C!ed requires entering a user.</p>|;

  $str .= htmlcode("openform");

  my $isEDev = $APP->isDeveloper($USER);
  my $isDevServer = 0;
  my $orderby = $query->param('orderby');
  my $useraction = $query->param('useraction');
  $useraction ||= '';


  my %orderhash = (
    'tstamp DESC' => 'Most Recently Cooled',   # coolwriteups
    'tstamp ASC' => 'Oldest Cooled',           # coolwriteups
    'title ASC' => 'Title(needs user)',        # node
    'title DESC' => 'Title (Reverse)' ,        # node
    'reputation DESC, title ASC' => 'Highest Reputation', # writeup
    'reputation ASC, title ASC' => 'Lowest Reputation',   # writeup
    'cooled DESC, title ASC' => 'Most Cooled',            # writeups
  );

  my $offset = $query->param('place');
  $offset ||= 0;

  $orderby = '' unless exists $orderhash{$orderby};

  $orderby ||= 'tstamp DESC';

  my @ordervals = keys %orderhash;

  $str.='Order by: '.$query->popup_menu('orderby', \@ordervals, $orderby, \%orderhash);
  $str.= ' and ';
  my @actions = ('cooled', 'written');
  $str.=$query->popup_menu('useraction', \@actions);
  $str.=' by user: ';
  $str.= $query->textfield('cooluser', '', 15,30);


  $str.=htmlcode('closeform');

  my $user = $APP->htmlScreen($query->param('cooluser'));

  # Select 51 rows so that we know, if 51 come back, we can provide a "next" link
  #  even though we always display 50 at most
  my $pageSize = 50;
  my $limit    = $pageSize + 1;

  my ($csr, $wherestr, $coolQuery) = (undef, undef, undef);

  if($user)
  {
    my $U = getNode($user, 'user');
    return $str . "<br />Sorry, no '$user' is found on the system!" unless $U;

    if ($useraction eq 'cooled')
    {
      $coolQuery = qq|
        select node.*, writeup.*, cw.*
        from 
         (select * from coolwriteups where cooledby_user = ? ) cw
        inner join node
          on node.node_id = cw.coolwriteups_id
        inner join writeup
          on writeup.writeup_id = node.node_id
        order by $orderby
        limit ?
        offset ?|;

      $csr = $DB->{dbh}->prepare($coolQuery);
      $csr->execute(getId($U), $limit, $offset);

    } elsif ($useraction eq 'written') {

      $coolQuery = qq|
        select nd.*, writeup.*, coolwriteups.*
        from 
        (select * from node where author_user = ? ) nd 
        inner join coolwriteups
        on coolwriteups.coolwriteups_id = nd.node_id
        inner join writeup
        on writeup.writeup_id = nd.node_id
        where writeup.cooled != 0
        order by $orderby
        limit ?
        offset ?|;

        $csr = $DB->{dbh}->prepare($coolQuery);
        $csr->execute(getId($U), $limit, $offset);

    }

  } elsif($orderby =~ /^(title|reputation|cooled) (ASC|DESC)/) {

    return $str . '<br>To sort by title, reputation, or number of C!s, a user name must be supplied.';

  } else {

    # Ordered by tstamp
    # We can do sorting and limiting in sub-query because it contains our sort field

    # We use "bigLimit" instead of the default limit because it's possible for
    #  a bunch of cools to point to writeups which no longer exist.  This is our hacky way
    #  of making sure paging still works ($limit or more results are necessary to trigger
    #  the "next" link) without doing a huge join
    my $bigLimit = 10 * $limit;

    $coolQuery = qq|
      select node.*, writeup.*, cw.*
      from 
      (select * from coolwriteups order by $orderby limit ? offset ? ) cw
      inner join writeup
        on writeup.writeup_id = cw.coolwriteups_id
      inner join node
        on node.node_id = cw.coolwriteups_id|;

    $csr = $DB->{dbh}->prepare($coolQuery);
    $csr->execute($bigLimit, $offset);

  }
 
  return encodeHTML($coolQuery) unless $csr;

  if ($isEDev and $isDevServer)
  {
    my $total = $csr->rows;
    $str .= "<h3>Query Debug</h3>";
    $str .= "<pre>" . encodeHTML($coolQuery) . "</pre>" if $isEDev;
    $str .= "orderby: " . encodeHTML($orderby) . "<br>"
      . "limit: " . encodeHTML($limit) . "<br>"
      . "offset: " . encodeHTML($offset) . "<br>"
      . "<strong>total: " . encodeHTML($total) . "</strong><br>";
  }

  $str.='<table width="100%" cellpadding="0" cellspacing="0">';
  $str.='<tr>';
  $str.='<th>Writeup</th><th>Written by</th><th>Cooled By</th></tr>';

  my $count = 0;

  $str .= htmlcode('show content', $csr,
    '<tr class="&oddrow">"<td>",parenttitle, type, "</td><td>", author, "</td><td>", cooledby, "</td>"',
    cansee => sub{
      return 1 unless ++$count > $pageSize;
      0;
    },
    cooledby => sub{
      linkNode($_[0]->{cooledby_user});
    }
  );

  $csr->finish;

  $str.='<tr><td>';
  $str.=linkNode($NODE, "<--last $pageSize", {orderby => $orderby, 
    cooluser => $user, 
    useraction => $useraction, 
    place => $offset - $pageSize})
  if $offset >= $pageSize;

  $str.='</td><td colspan="2" align="right">';
  $str.=linkNode($NODE, "next $pageSize-->", {orderby => $orderby,
    cooluser => $user, 
    useraction => $useraction, 
    place => $offset + $pageSize})
  if $count > $pageSize;

  $str.='</td></tr>';
  $str.='</table>';
  return $str;

}

sub create_a_registry
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my $str = qq|<p>Registries are places where people can share snippets of information about themselves, like their [email address] or [favourite vegetables].</p>|;

  $str .= qq|<p>Before you create any new registries, you should have a look at [the registries] we already have.</p>|;

  $str .= htmlcode("openform");

  if($query->param('sexisgood'))
  {
    return $str;
  }

  if($APP->getLevel($USER) < 8)
  {
    return "You would need to be [The Everything2 Voting/Experience System|level 8] to create a registry." unless $APP->getLevel($USER);

  }

  my $labels = ['key','value'];
  my $rows = [
    {'key'=>'Title','value'=>
     '<input type="text" name="node" size="40" maxlength="255">
      <input type="hidden" name="op" value="new">
      <input type="hidden" name="type" value="registry">
      <input type="hidden" name="displaytype" value="display">'
    },
    {'key'=>'Description', 'value'=>
     '<textarea name="registry_doctext" rows="7" cols="50"></textarea>'
    },
    {'key'=>'Answer style', 'value'=>
     $query->popup_menu(-name=>'registry_input_style', -values=>['text','yes/no','date'])
    },
    {'key'=>' ','value'=>
     '<input type="submit" name="sexisgood" value="create">'}
  ];
  $str .= $APP->buildTable($labels,$rows,'nolabels');
  $str .= qq|</form>|;
  return $str;
}

sub create_category
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><b><big>[Everything2 Help] &gt; [Everything2 Categories]</big></b></p>|;

  $str .= "<p>A [category] is a way to group a list of related nodes. You can create a category that only you can edit, a category that anyone can edit, or a category that can be maintained by any [Everything2 Usergroups|usergroup] you are a member of.</p>";

  $str .= qq|<p>The scope of categories is limitless. Some examples might include:</p>|;

  $str .= qq|<ul>|;
  $str .= qq|<li>$USER->{title}'s Favorite Movies</li>|;
  $str .= qq|<li>The Definitive Guide To Star Trek</li>|;
  $str .= qq|<li>Everything2 Memes</li>|;
  $str .= qq|<li>Funny Node Titles</li>|;
  $str .= qq|<li>The Best Books of All Time</li>|;
  $str .= qq|<li>Albums $USER->{title} Owns</li>|;
  $str .= qq|<li>Writeups About Love</li>|;
  $str .= qq|<li>Angsty Poetry</li>|;
  $str .= qq|<li>Human Diseases</li>|;
  $str .= qq|<li>... the list could go on and on</li>|;
  $str .= qq|</ul>|;

  $str .= "<p>Before you create your own category you might want to visit the [Display Categories|category display page] to see if you can contribute to an existing category.</p>";

  my $guestUser = $Everything::CONF->guest_user;
  #
  # Filter people out who can't create categories
  #
  if ( $APP->isGuest($USER) )
  {
    $str .= "You must be [login|logged in] to create a category.";
    return $str;
  }

  if ( $APP->getLevel($USER) <= 1 )
  {
     $str.='Note that until you are at least Level 2, you can only add your own writeups to categories.';
  }

  # this check may or may not be needed/wanted
  my $userlock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$USER{user_id}");
  if ($userlock)
  {
    return 'You are forbidden from creating categories.';
  }

  #
  # Output Form
  #

  $str .= $query->startform;
  $query->param("node", "");
  $str .= '<p><b>Category Name:</b><br />';
  $str .= $query->textfield(-name => "node",
    -default => "",
    -size => 50,
    -maxlength => 255);
  $str .= '</p><p><b>Maintainer:</b><br />';

  # Get usergroups current user is a member of
  my $sql = "SELECT DISTINCT ug.node_id,ug.title 
    FROM node ug,nodegroup ng 
    WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$$USER{user_id} ORDER BY ug.title";
  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  my $catType = getId(getType('category'));
  my @vals = ();
  my %txts = ();

  # current user
  $txts{$$USER{user_id}} = "Me ($$USER{title})";
  push @vals, $$USER{user_id};
  # guest user will be used for "Any Noder"
  $txts{$guestUser} = "Any Noder";
  push @vals, $guestUser;
  while(my $ug = $ds->fetchrow_hashref)
  { 
    $txts{$$ug{node_id}} = $$ug{title} . " (usergroup)";
     push @vals, $$ug{node_id};
  }

  $str .= $query->popup_menu("maintainer", \@vals, "", \%txts );

  my @customDimensions = htmlcode('customtextarea');

  # clear op which is set to "" on page load
  # also clear 'type' which may have been set to navigate to this page
  $query->delete('op', 'type');

  $str .= '</p>'
    . '<fieldset><legend>Category Description</legend>'
    . $query->textarea(
      -name => "category_doctext"
      , -id => "category_doctext"
      , -class => "formattable"
      , @customDimensions
    )
    . '</fieldset>'
    . $query->hidden(-name => "op", -value => "new")
    . $query->hidden(-name => "type", -value => $catType);

  $str .= $query->submit("createit", "Create It!");
  $str .= $query->endform;

  return $str;
}

sub create_room
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isChanop = $APP->isChanop($USER);

  if ($APP->getLevel($USER) < $Everything::CONF->create_room_level
    and not isGod($USER)
    and not $isChanop)
  {
    return "<I>Too young, my friend.</I>";
  }

  my $str = "";

  if ($APP->isSuspended($USER, 'room'))
  {
    return '<h2 class="warning">You\'ve been suspended from creating new rooms!</h2>';
  }

  $query->delete('op', 'type', 'node');
  $str.=$query->start_form;
  $str.=$query->hidden(-name => 'op', -value => 'new');
  $str.=$query->hidden(-name => 'type', -value => 'room');
  $str.='Room name: ';
  $str.=$query->textfield(-name => 'node', -size => 28, -maxlenght => 80);
  $str.="<P>And a few words of description: "
    .$query->textarea("room_doctext", "", 5, 60, "", "wrap=virtual");
  $str.=$query->submit("enter");
  $str.=$query->end_form;

  return $str;
}

sub database_lag_o_meter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>|;

  my %stats = ();
  my %vars = ();

  my $csr = $DB->{dbh}->prepare('show status');
  $csr->execute;

  while (my ($key, $val) = $csr->fetchrow)
  {
    $stats{$key} = $val;
  }

  $csr->finish;
  $csr = $DB->{dbh}->prepare('show variables');
  $csr->execute;
  while (my ($key, $val) = $csr->fetchrow)
  {
    $vars{$key} = $val;
  }

  $csr->finish;

  $stats{smq} = sprintf("%.2f", 1000000*$stats{Slow_queries}/$stats{Queries});
  my $time = $stats{Uptime};
  my ($d,$h,$m,$s) = (0, 0, 0, 0);

  $d += int($time / (60*60*24));
  $time -= $d * (60*60*24);
  $h += int($time / (60*60));
  $time -= $h * (60*60);
  $m += int($time / (60));
  $time -= $m * (60);
  $s += int($time);

  my $uptime = sprintf("%d+%02d:%02d:%02d", $d, $h, $m, $s);

  $str .= "Uptime: $uptime<br>Queries: ". $APP->commifyNumber($stats{Queries});
  $str .= "<br>Slow (>$vars{long_query_time} sec): ";
  $str .= $APP->commifyNumber($stats{Slow_queries});
  $str .= qq|<br>Slow/Million: $stats{smq}<br>|;

  $str .= qq|<p>Slow/Million Queries is a decent barometer of how much lag the Database is hitting.  Rising=bad, falling=good.|;
  return $str;
}

sub decloaker
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><em>Or to drown my clothes, and say I was stripped.</em> --- [Parolles]</p>|;

  return qq|$str The Treaty of Algeron prohibits your presence.| if $APP->isGuest($USER);
  $APP->uncloak($USER, $VARS);
  $str .=  '...like a new-born babe....';

  return $str;
}

sub disable_actions
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return $query -> p('There is nothing here that you need.')
    .$query -> p('Honestly.') unless $APP->isEditor($USER);

  my $SETTINGSNODE = getNode( 'Disabled actions' , 'setting' ) ;
  my $disabled = getVars( $SETTINGSNODE ) ;

  my $id = $query->param( 'donode' );
  $id ||= $query -> param( 'lastnode_id' ) ;

  return $query -> p("This page is used to edit the actions available in the page header for an individual page or for a nodetype. You probably don't need it. To use it, click on the little 'x' next to the action links under the page title.") unless $id;

  my $donode = getNodeById( $id ) ;
  my $nodetype = $$donode{ type_nodetype } ;
  my %options = ( b => 'bookmarking' , c => 'editor cools' , w => 'weblogging' , a => 'adding to categories (why?)' ,
	L => 'changes to these settings (careful: hard to undo)' , O => 'nodetype options for this node' ) ;

  if ( $query->param( 'set' ) )
  {
    foreach my $x ( $id , $nodetype )
    {
      delete $$disabled{ $x } ;
      my $setting = '' ;
      foreach ( keys %options )
      {
        $setting .= $query -> param( $_.$x ) ;
      }
      $$disabled{ $x } = $setting if $setting ;
    }
    setVars( $SETTINGSNODE , $disabled ) ;
  }

  my $str = htmlcode( 'openform' , 'fred' ) ;
  foreach ( [ $id , $$donode{ type }{ title } . ' ' . linkNode( $donode ) ] ,
    [ $nodetype , 'nodetype ' . linkNode( $$donode{ type } ) ] )
  {
    my $x = $$_[0] ;
    $str .= "\n<p>For $$_[1] disable:</p>\n<p>" ;
    foreach ( 'b' , 'c' , 'w' , 'a' , 'L' , 'O' )
    {
      my $checked = '';
      $checked = ' checked="checked"' if $$disabled{ $x } =~ /$_/ ;
      $str .= qq!\n<label><input type="checkbox" name="$_$x" value="$_"$checked>$options{ $_ }</label><br>! if $options{ $_ } ;
    }

    $str .= "\n</p>" ;
    $options{ O } = 'these settings when individual nodes have their own' ;
  }

  $str .= qq|<p><input type="hidden" name="donode" value="$id"><input type="submit" name="set" value="Sumbit">|;
  $str .= qq|</p><p>Note: these settings only disable the links in page headers, not the functions themselves.</p>|;
  $str .= qq|</form>|;

  return $str;
}

sub display_categories
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $canContributePublicCategory = ($APP->getLevel($USER) >= 1);
  my $guestUser = $Everything::CONF->guest_user;
  my $uid = $$USER{user_id};
  my $isCategory = 0;
  my $linktype = getId(getNode('category', 'linktype'));

  my $sql = '';
  my $ds = undef;
  my $str = '';
  my $ctr = 0;

  my $count = 50;
  my $page = int($query->param('p'));
  if ($page < 0)
  {
    $page = 0;
  }

  my $maintainerName = $query->param('m');
  $maintainerName =~ s/^\s+|\s+$//g;
  my $maintainer = undef;

  if (length($maintainerName) > 0)
  {
    $maintainer = getNode($maintainerName, 'user');
    if (!$$maintainer{node_id})
    {
      $maintainer = getNode($maintainerName, 'usergroup');
      if (!$$maintainer{node_id})
      {
        $maintainerName = '';
        $$maintainer{node_id} = 0;
      }
    }
  }

  my $userType = getId(getType('user'));
  my $usergroupType = getId(getType('usergroup'));
  my $categoryType = getId(getType('category'));

  my $order = $query->param('o');

  $str .= qq|<form method="get" action="/index.pl">|;
  $str .= qq|<input type="hidden" name="node_id" value="|.getId($NODE);
  $str .= qq|" />|;
  $str .= qq|<table><tr><td><b>Maintained By:</b></td><td>|;
  $str .= $query->textfield(-name => "m",
    -default => $maintainerName,
    -size => 25,
    -maxlength => 255);

  $str .= qq| (leave blank to list all categories)</td>|;
  $str .= qq|</tr><tr><td><b>Sort Order:</b></td><td>|;
  $str .= qq|<select name="o">|;
  $str .= qq|<option value="">Category Name</option>|;
  $str .= qq|<option value="m">Maintainer</option>|;
  $str .= qq|</select></td></tr></table>|;
  $str .= $query->submit("submit", "Submit");
  $str .= $query->endform;

  my $contribute = "";
  $contribute = "<th>Can I Contribute?</th>" if !$APP->isGuest($USER);

  $str .= qq|<table width="100%"><tr>|;
  $str .= qq|<th>Category</th><th>Maintainer</th>$contribute</tr>|;

  my $orderBy = 'n.title,a.title';

  if ($order eq 'm')
  {
    $orderBy='a.title,n.title';
  }

  my $authorRestrict = "";
  $authorRestrict = "AND n.author_user = $$maintainer{node_id}\n" if ($$maintainer{node_id} > 0);

  my $startAt = $page * $count;

  $sql = "SELECT n.node_id, n.title, n.author_user
    , a.title AS maintainer
    , a.type_nodetype AS maintainerType
    FROM node n
    JOIN node a
    ON n.author_user = a.node_id
    WHERE n.type_nodetype = $categoryType
    $authorRestrict
    AND n.title NOT LIKE '%\_root'
    ORDER BY $orderBy
    LIMIT $startAt,$count";

  $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  while(my $n = $ds->fetchrow_hashref)
  {
    my $maintName = $$n{maintainer};
    my $maintId = $$n{author_user};
    my $isPublicCategory = ($guestUser == $maintId);

    $ctr++;
    if($ctr % 2 == 0)
    {
      $str .= '<tr class="evenrow">';
    }else{
      $str .= '<tr class="oddrow">';
    }
    $str .= '<td>'.linkNode($$n{node_id}, $$n{title}).'</td>';

    my $authorLink = linkNode($$n{author_user}, $maintName);
    $authorLink = "Everyone" if $isPublicCategory;
    $authorLink .= ' (usergroup)' if ($$n{maintainerType} == $usergroupType);

    $str .= qq'<td style="text-align:center">$authorLink</td>\n';

    if (!$APP->isGuest($USER))
    {
      $str .= '<td style="text-align:center">';
      if ($isPublicCategory && $canContributePublicCategory or $maintId == $uid)
      {
        $str .= '<b>Yes!</b>';
      }elsif ($$n{maintainerType} == $usergroupType && $APP->inUsergroup($uid, $maintName)){
        $str .= '<b>Yes!</b>';
      }else{
        $str .= 'No';
      }
      $str .= "</td>\n"
    }
  
    $str .= '</tr>';
  }

  if ($ctr <= 0)
  {
    $str .= '<tr><td colspan="2"><em>No categories found!</em></td></tr>';
  }
  $str .= '</table>';

  $str .= '<p style="text-align:center">';
  if ($page > 0)
  {
    $str .= '<a href="/index.pl?node_id='.getId($NODE).'&p='.($page-1).'&m='.$maintainerName.'&o='.$order.'">&lt;&lt; Previous</a>';
  }

  $str .= ' | <b>Page '.($page+1).'</b> | ';
  if ($ctr >= $count)
  {
    $str .= '<a href="/index.pl?node_id='.getId($NODE).'&p='.($page+1).'&m='.$maintainerName.'&o='.$order.'">Next &gt;&gt;</a>';
  }
  $str .= '</p>';

  return $str;

}

1;
