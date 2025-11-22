package Everything::Delegation::nodelet;

use strict;
use warnings;

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *getType = *Everything::HTML::getType;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
}

sub epicenter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # React component handles all rendering
  # The Perl function remains for nodelet framework compatibility
  return "";
}

sub new_writeups
{
  return "";
}

sub other_users
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("changeroom","Other Users");
  $str = "" if not defined($str);

  my $wherestr = "";

  $$USER{in_room} = int($USER->{in_room});
  $USER->{in_room} = 0 unless $DB->getNodeById($USER->{in_room});
  if ($$USER{in_room}) {
    $wherestr = "room_id=$$USER{in_room} OR room_id=0";
  }

  my $UID = $$USER{node_id};
  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  my $isChanop = $APP->isChanop($USER);

  unless ($isCE || $$VARS{infravision}) {
    $wherestr.=' AND ' if $wherestr;
    $wherestr.='visible=0';
  }

  my $showActions = $$VARS{showuseractions} ? 1 : 0;

  my @doVerbs = ();
  my @doNouns = ();
  if ($showActions)
  {
    @doVerbs = ('eating', 'watching', 'stalking', 'filing',
              'noding', 'amazed by', 'tired of', 'crying for',
              'thinking of', 'fighting', 'bouncing towards',
              'fleeing from', 'diving into', 'wishing for',
              'skating towards', 'playing with',
              'upvoting', 'learning of', 'teaching',
              'getting friendly with', 'frowned upon by',
              'sleeping on', 'getting hungry for', 'touching',
              'beating up', 'spying on', 'rubbing', 'caressing', 
              ''        # leave this blank one in, so the verb is
                        # sometimes omitted
    );
  @doNouns = ('a carrot', 'some money', 'EDB', 'nails', 'some feet',
              'a balloon', 'wheels', 'soy', 'a monkey', 'a smurf',
              'an onion', 'smoke', 'the birds', 'you!', 'a flashlight',
              'hash', 'your speaker', 'an idiot', 'an expert', 'an AI',
              'the human genome', 'upvotes', 'downvotes',
              'their pants', 'smelly cheese', 'a pink elephant',
              'teeth', 'a hippopotamus', 'noders', 'a scarf',
              'your ear', 'killer bees', 'an angst sandwich',
              'Butterfinger McFlurry'
    );
  }

  my $newbielook = $isRoot || $isCE;

  my $powStructLink = '<a href='.urlGen({'node'=>'E2 staff', 'nodetype'=>'superdoc'})
                    . ' style="text-decoration: none;" ';
  my $linkRoots = $powStructLink . 'title="e2gods">@</a>';
  my $linkCEs = $powStructLink . 'title="Content Editors">$</a>';

  my $linkChanops = $powStructLink.'title="chanops">+</a>';

  my $linkBorged = '<a href='.urlGen({'node'=>'E2 FAQ: Chatterbox',
                                   'nodetype'=>'superdoc'})
                 .' style="text-decoration: none;" title="borged!">&#216;</a>';

  # no ordering from databse - sorting done entirely in perl, below
  my $csr = $DB->sqlSelectMany('*', 'room', $wherestr);

  my $num = 0;
  my $sameUser;   # if the user to show is the user that is loading the page
  my $userID;     # only get member_user from hash once
  my $n;          # nick

  # Fetch users to ignore.
  my $ignorelist = $DB->sqlSelectMany('ignore_node', 'messageignore',
                                    'messageignore_id='.$UID);
  my (%ignore, $u);
  $ignore{$u} = 1 while $u = $ignorelist->fetchrow();
  $ignorelist->finish;

  my @noderlist;
  while(my $U = $csr->fetchrow_hashref())
  {
    $num++;
    $userID = $$U{member_user};

    my $jointime = $APP->convertDateToEpoch($DB->getNodeById($userID)->{createtime});

    my $userVars = getVars($DB->getNodeById($userID));

    my ($lastnode,$lastnodetime, $lastnodehidden);
    my $lastnodeid =  $userVars -> {lastnoded};
    if ($lastnodeid)
    {
      $lastnode = $DB->getNodeById($lastnodeid);
      $lastnodetime = $lastnode -> {publishtime};
      $lastnodehidden = $lastnode -> {notnew};

      # Nuked writeups can mess this up, so have to check there really
      # is a lastnodetime.
      $lastnodetime = $APP->convertDateToEpoch($lastnodetime) if $lastnodetime;
    }

    #Haven't been here for a month or haven't noded?
    if( time() - $jointime  < 2592000 || !$lastnodetime ){
      $lastnodetime = 0;
    }

    my $thisChanop = $APP->isChanop($userID,"nogods");

    $sameUser = $UID==$userID;
    next if $ignore{$userID} && !$isRoot;
    $n = $$U{nick};
    my $nameLink = linkNode($userID, $n);

    if (htmlcode('isSpecialDate','halloween'))
    {
      my $bAndBrackets = 1;
      my $costume = $$userVars{costume};
      if (defined $costume and $costume ne '')
      {
        $costume = $APP->encodeHTML($$userVars{costume}, $bAndBrackets);
        $nameLink = linkNode($userID, $costume);
      }
    }
    $nameLink = '<strong>'.$nameLink.'</strong>' if $sameUser;

    my $flags='';
    if ($APP->isAdmin($userID) && !$APP->getParameter($userID,"hide_chatterbox_staff_symbol") )
    {
      $flags .= $linkRoots;
    }

    if ($newbielook)
    {
      my $getTime = $DB->sqlSelect("datediff(now(),createtime)+1 as "
                                 ."difftime","node","node_id="
                                 .$userID." having difftime<31");

      if ($getTime)
      {
        if ($getTime<=3)
        {
          $flags.='<strong class="newdays" title="very new user">'.$getTime.'</strong>';
        } else {
          $flags.='<span class="newdays" title="new user">'.$getTime.'</span>'
        }
      }
    }

    if ($APP->isEditor($userID, "nogods") && !$APP->isAdmin($userID) && !$APP->getParameter($userID,"hide_chatterbox_staff_symbol") )
    {
      $flags .= $linkCEs;
    }

    $flags .= $linkChanops if $thisChanop;

    if ($isCE || $isChanop)
    {
      $flags .= $linkBorged if $$U{borgd}; # yes, no 'e' in 'borgd'
    }
    if ($$U{visible})
    {
      $flags.='<font color="#ff0000">i</font>';
    }

    if ($$U{room_id} != 0 and $$USER{in_room} == 0)
    {
      my $rm = getNodeById($$U{room_id});
      $flags .= linkNode($rm, '~');
    }

    $flags = ' &nbsp;[' . $flags . ']' if $flags;

    my $nameLinkAppend = "";

    if ($showActions && !$sameUser && (0.02 > rand()))
    {
      $nameLinkAppend = ' <small>is ' . $doVerbs[int(rand(@doVerbs))] 
                      . ' ' . $doNouns[int(rand(@doNouns))] 
                      . '</small>';
    }

    # jessicaj's idea, link to a user's latest writeup
    if ($showActions && (0.02 > rand()) )
    {
      if ((time() - $lastnodetime) < 604800 # One week since noding?
        && !$lastnodehidden) {
        my $lastnodeparent = getNodeById($$lastnode{parent_e2node});
        $nameLinkAppend = '<small> has recently noded '
                        . linkNode($lastnode,$$lastnodeparent{title})
                        . ' </small>';
      }

    }

    $nameLink .= $nameLinkAppend;

    $n =~ tr/ /_/;

    my $thisnoder = $nameLink . $flags;

    #Votes only get refreshed when user logs in
    my $activedays = $userVars->{votesrefreshed} || 0;

    # Gotta resort the noderlist by recent writeups and XP
    push @noderlist, {
        'noder' => $thisnoder
        , 'lastNodeTime' => $lastnodetime
        , 'activeDays' => $activedays
        , 'roomId' => $$U{room_id}
     };
  }
  $csr->finish;

  return '<em>There are no noders in this room.</em>' unless $num;
  # sort by latest time of noding, tie-break by active days if
  # necessary, [alex]'s idea

  @noderlist = sort {
    ($$b{roomId} == $$USER{in_room}) <=> ($$a{roomId} == $$USER{in_room})
    || $$b{roomId} <=> $$a{roomId}
    || $$b{lastNodeTime} <=> $$a{lastNodeTime}
    || $$b{activeDays} <=> $$a{activeDays}
  } @noderlist;

  my $printRoomHeader = sub {
     my $roomId = shift;
     my $roomTitle = 'Outside';
     if ($roomId != 0)
     {
       my $room = getNodeById($roomId);
       $roomTitle = $room && $$room{type}{title} eq 'room' ?
                        $$room{title} : 'Unknown Room';
     }
     return "<div>$roomTitle:</div>\n<ul>\n";
  };

  my $lastroom = $noderlist[0]->{roomId};
  $str .= "<ul>\n";
  foreach my $noder(@noderlist)
  {
    if ($$noder{roomId} != $lastroom)
    {
      $str .= "</ul>\n";
      $str .= &$printRoomHeader($$noder{roomId});
    }

    $lastroom = $$noder{roomId};
    $str .= "<li>$$noder{noder}</li>\n";
  }

  $str .= "</ul>\n";

  my $intro = '<h4>Your fellow users ('.$num.'):</h4>';
  $intro .= '<div>in '.linkNode($$USER{in_room}). ':</div>' if $$USER{in_room};

  return $intro . $str;

}

sub sign_in
{
  return "";
}

sub recommended_reading
{
  return '';
}

sub vitals
{
  return '';
}

sub chatterbox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str='';

  $str .= htmlcode("openform2","formcbox");

  # get settings here in case they are being updated. Slight kludge to remember them...
  $PAGELOAD->{chatterboxsettingswidgetlink} = htmlcode('nodeletsettingswidget','Chatterbox', 'Chatterbox settings');
  unless($$VARS{hideprivmessages})
  {

    my $messagesID = getNode('Messages', 'nodelet') -> { node_id } ;
    unless($$VARS{ nodelets } =~ /\b$messagesID\b/)
    {

      my $msgstr = htmlcode('showmessages','10');
      my $hr = "";
      $hr = '<hr width="40%">' if $msgstr;
      $str .= qq|<div id="chatterbox_messages">$msgstr</div>$hr|;
    }
  }

  $str .= qq|<div id='chatterbox_chatter'>|.htmlcode("showchatter").qq|</div><a name='chatbox'></a>|;

  unless($APP->isGuest($USER))
  {
    my $msgstr = '<input type="hidden" name="op" value="message" /><br />'."\n\t\t";
    $query->param('message','');

    #show what was said
    if(defined $query->param('sentmessage'))
    {
      my $told = $query->param('sentmessage');
      my $i=0;
      while(defined $query->param('sentmessage'.$i))
      {
        $told.="<br />\n\t\t".$query->param('sentmessage'.$i);
        ++$i;
      }
      $told=parseLinks($told,0) unless $$VARS{showRawPrivateMsg};
      $msgstr.="\n\t\t".'<p class="sentmessage">'.$told."</p>\n";
    }

    #borged or allow talk
    $msgstr .= htmlcode('borgcheck') || "";
    $msgstr .= $$VARS{borged}
    ? '<small>You\'re borged, so you can\'t talk right now.</small><br>' . $query->submit('message_send', 'erase')
    : "<input type='text' id='message' name='message' class='expandable' size='".($$NODE{title} eq "ajax chatterlight" ? "70" : "12")."' maxlength='512'>" . "\n\t\t" .
    $query->submit(-name=>'message_send', id=>'message_send', value=>'talk'). "\n\t\t";
;

    if ($APP->isSuspended($USER,"chat"))
    {
      my $canMsg = ($$VARS{borged}
                ? "chatting."
                : "public chat, but you can /msg other users.");
      $msgstr .= "<p><small>You are currently suspended from $canMsg</small></p>\n"
    }

    $msgstr.=$query->end_form;

    $msgstr .= "\n\t\t".'<div align="center"><small>'.linkNodeTitle('Chatterbox|How does this work?')." | ".linkNodeTitle('Chatterlight')."</small></div>\n" if $APP->getLevel($USER)<2;

    #Jay's topic stuff

    my $topicsetting = "";
    my $topic = '';

    unless($$VARS{hideTopic} )
    {
      $topicsetting = getVars(getNode('Room Topics', 'setting'));

      if(exists($$topicsetting{$$USER{in_room}}))
      {
        $topic = $$topicsetting{$$USER{in_room}};
        utf8::decode($topic);
        $topic = "\n\t\t".'<small>'.parseLinks($topic).'</small>'; #slighly different
      }

    }

    $str.=$msgstr.$topic;
  }

  $str .= qq|<div class="nodeletfoot">|;

  if($APP->isChanop($USER))
  {
    $str .= linkNode($NODE, 'silence', {'confirmop' => 'flushcbox',
	-class=>"action ajax chatterbox:updateNodelet:Chatterbox"}).'<br>';
  }

  if($USER->{in_room})
  {
    $str .= linkNodeTitle('go outside[superdocnolinks]').'<br>';
  }
  
  $str .= $PAGELOAD->{chatterboxsettingswidgetlink}. qq|</div>|;
  return $str;
}

sub personal_links
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str='';

  return 'You must log in first.' if $APP->isGuest($USER);

  # do this here to update settings before showing nodelet:
  my $settingslink = htmlcode('nodeletsettingswidget','Personal Links', 'Edit link list');

  my $limit=50;

  my $UID = getId($USER) || 0;
  if( $APP->isEditor($USER) ) {
	$limit += 20;
  }
  my @nodes = split('<br>',$$VARS{personal_nodelet});
  if (my $n = $query->param('addpersonalnodelet'))
  {
    return "<b>Security Error</b>" unless htmlcode('verifyRequest', 'personalnodelet');
    $n = $DB->getNodeById($n);
    if ($$VARS{personal_nodelet} !~ /$$n{title}/)
    {
      $$VARS{personal_nodelet} .= '<br>'.$$n{title} if @nodes < $limit;
      push @nodes, $$n{title};
    }
  }

  $str .= '<ul class="linklist">' ;
  my $i=0;
  foreach(@nodes)
  {
    next unless $_;
    $str.= "\n<li>".linkNodeTitle($_)."</li>";
    last if $i++ >= $limit;
  }

  $str .= "\n</ul>\n" ;

  my $t = $$NODE{title};
  $t =~ s/(\S{16})/$1 /g;

  $str .= '<div class="nodeletfoot">' ;
  $str .= linkNode($NODE, "add \"$t\"", {-class => 'action',
	-title => 'Add this node to your personal nodelet list. This list can be edited in Nodelet Settings',
	addpersonalnodelet => $$NODE{node_id}, %{htmlcode('verifyRequestHash', 'personalnodelet')}} ).'<br>'
	if @nodes < $limit ;

  $str .= $settingslink . '</div>';

  if($APP->isAdmin($USER))
  {
    $str .= '<hr width="100" /><small><strong>node bucket</strong></small><br>';
    my $PARAMS = { op => 'addbucket', 'bnode_' . $$NODE{node_id} => 1, -class=>'action' };
    my $title = $$NODE{title};
    $title =~ s/(\S{16})/$1 /g;
    $str .= linkNode($NODE, "Add '$title'", $PARAMS);

    my @bnodes = ();
    @bnodes = split ',', $$VARS{nodebucket} if (defined($$VARS{nodebucket}));
    my $isGroup = 0;
    $isGroup = 1 if $$NODE{type}{grouptable};

    if(scalar(@bnodes) == 0)
    {
      $str.="<p>Empty<br>\n";
    }else{
      $str.= htmlcode('openform');
      $str.=$query->hidden(-name => "op", -value => 'bucketop', force=>1);

      my $ajax = '&op=/';
      my @newbnodes;
      foreach my $id (@bnodes)
      {
        my $node=$DB->getNodeById($id);
        next unless $node;
        push @newbnodes, $id;
        $str .= qq'<input type="checkbox" name="bnode_$$node{node_id}" value="1">'.
  	  linkNode($node, undef, {lastnode_id => undef}) . "<br>\n";
        $ajax .= "&bnode_$$node{node_id}=/";
      }

      $str .= "<input type='checkbox' name='dropexec' value='1' checked='checked'>" . "Execute and drop<br>\n" if($isGroup);

      if($isGroup)
      {
	$str .= $query->submit( -name => "bgroupadd", -value => "Add to Group",
		-class => "ajax personallinks:updateNodelet?bgroupadd=1$ajax:Personal+Links") ."\n";
      }

      $str .= $query->submit( -name => 'bdrop', -value => 'Drop',
		-class => "ajax personallinks:updateNodelet?bdrop=1$ajax:Personal+Links") . "\n";

      $VARS->{nodebucket} = join(",",@newbnodes);

      $str.='</form>';
    }
  }

  return $str;
}

sub random_nodes
{
  return "";
}

sub everything_developer
{
  return "";
}

sub statistics
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  $$VARS{numwriteups} ||=0;
  $$VARS{IQM} ||=0;

  my $str = "";
  $str .= htmlcode('nodeletsection','stat,personal,Yours,,,i');
  $str .= htmlcode('nodeletsection','stat,fun,Fun Stats,,,i');
  $str .= htmlcode('nodeletsection','stat,advancement,Old Merit System,,,i'); 

  return $str;
}

sub readthis
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # React component handles all rendering
  # The Perl function remains for nodelet framework compatibility
  return "";
}

sub notelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  if((exists $VARS->{lockCustomHTML}) || (exists $VARS->{noteletLocked}))
  {
    #latter way is deprecated
    #may later say why locked? or give a msg field to anon admin?
    return 'Sorry, your Notelet is currently locked, probably because an administrator is working with your account. It should soon be back to normal.';
  }

  #message to display if text not set
  #(urlGen instead parseLinks to foil pranksters making e2nodes with same title)
  my $blankMsg = 'You currently have no text set for your personal nodelet. You can edit it at <a href='.
    urlGen({'node'=>'Notelet Editor','type'=>'superdoc'}).'>Notelet Editor</a> or <br>'.
    linkNode($NODE, 'remove it here', {
      op => 'movenodelet',
      position => 'x',
      nodelet => 'Notelet',
      -id => 'noteletremovallink',
      -class => 'ajax (noteletremovallink):ajaxEcho:'
      .q!remove+it+here!
      .q!&lt;script+type='text/javascript'&gt;!
      .q!e2.vanish($('#notelet'));&lt/script&gt;!
      }).' or at your <a href='.urlGen({'node'=>'Nodelet Settings','type'=>'superdoc'}).'>Nodelet Settings</a>';

  unless ((exists $VARS->{'noteletRaw'}) && length($VARS->{'noteletRaw'}))
  {
    $str .= $blankMsg;
  }else{
    unless(exists $VARS->{'noteletScreened'})
    {
      htmlcode('screenNotelet','');
      $str .= $blankMsg unless ((exists $VARS->{'noteletRaw'}) && length($VARS->{'noteletRaw'}));
    }else{
      $str .= parseLinks($VARS->{'noteletScreened'});
    }
  }

  $str .=qq|<div class="nodeletfoot">(|.linkNode(getNode('Notelet editor','superdoc'),'edit').qq|)</div>|;
  return $str;
}

sub recent_nodes
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  $$VARS{nodetrail} ||= "";
  my @list = split(",",$$VARS{nodetrail});
  #put this node_id at the top of the list for next time
  $$VARS{nodetrail} = $$NODE{node_id} . ',';

  return '<small><em>All forgotten...</em></small>' if $query->param('eraseTrail');

  my @sayings = ("A trail of crumbs", "Footprints in the sand",
		"Are we there yet?", "A snapshot...", "The ghost of nodes past");

  $str = '<em>'.$sayings[(rand(@sayings))].'</em>';
  return unless scalar @list;

  my $i=0;
  my $list = '';
  foreach (@list) {
    next unless $_;
    next unless $$VARS{nodetrail} !~ /\b$_\b/; 	#skip dupes
    $list .= "<li>" . linkNode($DB->getNodeById($_), undef, {"lastnode_id" => 0}) . "</li>";
    $$VARS{nodetrail} .= $_ . ',' ; #push this onto the bottom of the list
    last if ++$i > 8;
  }
  my @quotes = ("Cover my tracks", "Deny my past", "The Feds are knocking", "Wipe the slate clean");
	$str .= ":\n<ol>$list\n</ol>\n".
		htmlcode('openform', -class => 'nodeletfoot').
		$query -> hidden('eraseTrail','1').
		$query -> submit('schwammdrueber', $quotes[(rand(@quotes))]).
	'</form>' if $list;

  return $str;

}

sub master_control
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # React component handles all rendering
  # The Perl function remains for nodelet framework compatibility
  return "";
}

sub current_user_poll
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode('showcurrentpoll',"in nodelet");
}

sub favorite_noders
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  $$VARS{favorite_limit} = int($query->param("fave_limit")) if (int($query->param("fave_limit")));

  my $wuLimit = int($$VARS{favorite_limit}) || 15;
  $wuLimit = 50 if ($wuLimit > 50 || $wuLimit < 1);

  my $linktypeFavorite = getNode('favorite', 'linktype');
  return '' unless $linktypeFavorite;
  my $linktypeIdFavorite = $$linktypeFavorite{node_id};
  my $typeIdWriteup = getType('writeup')->{node_id};
  my $str = '';

  $str .= htmlcode('openform'). '<label>Limit: '. $query->textfield(-name => 'fave_limit', -size => 3 )
  . '</lable>'
  . $query->submit("sexisgood","update")
  . $query->end_form();

  my $queryStringFavorites = <<SQLEND;
    SELECT node.node_id, node.author_user
    FROM links
    JOIN node
      ON links.to_node = node.author_user
    WHERE links.linktype = $linktypeIdFavorite
      AND links.from_node = $$USER{user_id}
      AND node.type_nodetype = $typeIdWriteup
    ORDER BY node_id
    DESC LIMIT $wuLimit
SQLEND

  my $writeuplist = $DB->getDatabaseHandle()->selectall_arrayref($queryStringFavorites);

  my $wuListText = "<ul id='writeup_faves'>";

  for my $n (@$writeuplist) {
    my $N = $DB->getNodeById($$n[0]);
    $wuListText .=
      "<li><span class='writeupmeta'><span class='title'>".linkNode($$N{node_id})."</span> "
      . "by <span class='author'>".linkNode($$N{author_user})."</span></span></li>";
  }

  $wuListText .="</ul>";
  return $str . $wuListText;
}

sub new_logs
{
  return "";
}

sub usergroup_writeups
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isEd = $APP->isEditor($USER);
  my $webloggables = getVars(getNode("webloggables", "setting"));
  my $view_weblog ="";
  # It might be more efficient to use a node_id for the VARS, but I'm not sure it'd make enough difference to be worth changing.
  my $ug=getNode("$$VARS{nodeletusergroup}"||"E2science","usergroup");
  $view_weblog=getId($ug);

  # Most of the next chunk of code is pulled from [news archives].

  my @labels = ();
  my $counter = 0;
  my $limit = 14;

  my @groups = ();



  foreach my $node_id (sort {
        lc($$webloggables{$a}) cmp lc($$webloggables{$b})
      } keys(%$webloggables)){
    my $title =  $$webloggables{$node_id};
    my $wclause = "weblog_id='$node_id' AND removedby_user=''";
    my $count = $DB->sqlSelect('count(*)','weblog',"$wclause");
    my $link = linkNode($NODE,$title,{'view_weblog'=>"$node_id"});
    $link = "<b>$link</b>" if $node_id == $view_weblog;
    push @labels, "$link<br><small>($count node".
    ($count==1?'':'s').')</small>';
  }

  my $text = "";

  return $text if (($view_weblog == 114)||($view_weblog==923653))&&(!($isEd));

  $text .= '<p align="center">'.
           linkNode($ug).' writeups</p>';

  $text .= '<ul class="linklist">';
  my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
  my $csr = $DB->sqlSelectMany('*','weblog',$wclause,'order by tstamp desc');
  while(($counter <= $limit) && (my $ref = $csr->fetchrow_hashref())){
    my $N = getNode($$ref{to_node});
    next unless $N;
    my $link = linkNode($N);
    $text .= "<li>$link</li>\n";
    $counter++;
  }
  $text .= "</ul>";


  # Pull a list of node_ids for groups the user can weblog to:

  my $can_weblog=$$VARS{can_weblog};
  my @groupids=split(',', $can_weblog);
  # Put in a menu so the user can choose different groups:

  $$VARS{nodeletusergroup} = 'E2science' unless $$VARS{nodeletusergroup};

  my $str = htmlcode('openform');

  $str.="\n\t<input type='hidden' name='op' value='changeusergroup'>";
  $str.="\n\t<select name='newusergroup' class='ajax usergroupwriteups:updateNodelet?op=/op&newusergroup=/newusergroup:Usergroup Writeups'>";

  # get the titles of all the usergroups we need. I bet there's a more efficient way of doing this.
  for(@groupids)
  {
    push (@groups, $DB->getNodeById($_,"light")->{title});
  }

  for(@groups)
  {
    $str.="\n\t\t<option value=\"$_\"";
    $str.=' selected="selected"' if $_ eq $$VARS{nodeletusergroup};
    $str.=">$_</option>";
  }
  $str.="\n\t</select>";
  $str.="\n\t".$query->submit("sexisgood","show");
  $str.="\n".$query->end_form;
  $text.=$str;

  return $text;

}

sub notifications
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<ul id='notifications_list'>|;
  # show settings dialog if no notifications active
  $query -> param('showwidget', 'notificationssettings') unless $$VARS{settings} || ($$NODE{title} eq 'Nodelet Settings' && $$NODE{type}{title} eq 'superdoc');
  # do this here to update settings before showing nodelet:
  my $settingslink = htmlcode('nodeletsettingswidget','Notifications', 'Notification settings');

  my $notification_list = htmlcode('notificationsJSON', 'wrap'); # 'wrap' to get markup for list
my $notify_count = 1;

  while (defined $$notification_list{$notify_count}) {
    my $notify = $$notification_list{$notify_count};
    $str .= "$$notify{value}\n";
    $notify_count++;
  }

return $str.qq'\n</ul>\n<div class="nodeletfoot">\n$settingslink\n</div>';

}

sub categories
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $GU = $Everything::CONF->guest_user;
  my $uid = $$USER{user_id};

  my $str = "";

  my $sql = "SELECT DISTINCT ug.node_id
    FROM node ug,nodegroup ng 
    WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$uid";

  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  my $inClause = $uid.','.$GU;
  while(my $n = $ds->fetchrow_hashref)
  {
    $inClause .= ','.$$n{node_id};
  }

  # Now get all the categories the user can edit
  $sql = "SELECT n.node_id, n.author_user
    FROM node n
    WHERE author_user IN ($inClause)
    AND type_nodetype=1522375
    AND  node_id NOT IN (SELECT to_node AS node_id FROM links WHERE from_node=n.node_id)
    ORDER BY n.title";

  $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  my $ctr = 0;
  my $strList = "";
  while(my $n = $ds->fetchrow_hashref)
  {
    $ctr++;
    $strList .= '<li>'.linkNode($$n{node_id}, '', {lastnode_id=>0})
      .' by '.linkNode($$n{author_user}, '', {lastnode_id=>0})
      .' (<a href="/index.pl?op=category&node_id='.$$NODE{node_id}.'&cid='.$$n{node_id}.'&nid='.$$NODE{node_id}.'">add</a>)</li>';
  }

  $str .= '<ul id="nodelists">'
         .$strList
         .'</ul>
         <div class="nodeletfoot">'
        .linkNodeTitle('Create Category', 0, 'Add a new Category')
        .'</div>';

  return $str;

}

sub most_wanted
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<table>|;

  $str.="<p><table class='mytable'><tr><th>Requesting Sheriff</th><th>Outlaw Nodeshell</th><th>GP Reward (if any)</th></tr>";

  my $REQ = getVars(getNode('bounty order','setting'));
  my $OUT = getVars(getNode('outlaws', 'setting'));
  my $REW = getVars(getNode('bounties', 'setting'));
  my $HIGH = getVars(getNode('bounty number', 'setting'));
  my $MAX = 5;

  my $bountyTot = $$HIGH{1};
  my $numberShown = 0;
  my $outlawStr = "";
  my $requester = "";
  my $reward = "";

  for(my $i = $bountyTot; $numberShown < $MAX; $i--)
  {

    if (exists $$REQ{$i})
    {
      $numberShown++;
      my $requesterName = $$REQ{$i};
      $requester = linkNode(getNode($requesterName, 'user'));
      $outlawStr = parseLinks($APP->encodeHTML($$OUT{$requesterName}));
      $reward = $APP->encodeHTML($$REW{$requesterName});
      $str.="<tr><TD>$requester</TD><TD>$outlawStr</TD><TD>$reward</TD></tr>";
    }
  }

  $str.="<p><small>Fill these nodes and get rewards! More details at " . linkNodeTitle('Everything\'s Most Wanted') . "\.</small></p>";
  $str.=qq|</table>|;

return $str;

}

sub messages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return qq|<div id="messages_messages">|.htmlcode('testshowmessages').qq|</div>|;
}

sub neglected_drafts
{
  return '';
}

sub for_review
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my %funx = (
    startline => sub{
      $_[0] -> {type}{title} = 'draft';
      '<td>';
    },
    notes => sub{
      $_[0]{latestnote} =~ s/\[user\]//;
      my $note = $APP->encodeHTML($_[0]{latestnote}, 'adv');
      '<td align="center">'
      .($_[0]{notecount} ? linkNode($_[0], $_[0]{notecount},
      {'#' => 'nodenotes', -title => "$_[0]{notecount} notes; latest $note"})
      : '&nbsp;')
      .'</td>';
      }
  );

  my $drafts = $DB->stashData("reviewdrafts");

  return "<table><tr><th>Draft</th>".($APP->isEditor($USER)?(qq|<th align="center" title="node notes">N?</th>|):(""))."</tr>"
    .htmlcode('show content', $drafts
    , qq!<tr class="&oddrow"> startline, title, byline, "</td>",!.(($APP->isEditor($USER)?("notes"):(""))),%funx)
    .'</table>';

}

sub quick_reference
{
  return '';
}

1;
