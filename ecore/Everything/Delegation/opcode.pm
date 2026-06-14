package Everything::Delegation::opcode;
use Everything::SecurityLog qw(:events);

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

## no critic (ProhibitBuiltinHomonyms)

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup; 
} 

# Used by bookmark, cool, weblog, socialBookmark
use JSON;

sub publishdraft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;
  # turn a draft into a writeup and pass it on for insertion into an e2node

  my $e2node = $query -> param('writeup_parent_e2node');

  my $draft = $query -> param('draft_id');
  getRef $draft;

  return unless ($draft and $$draft{doctext} and ($$draft{type}{title} eq 'draft') and
    ( ($$USER{node_id} == $$draft{author_user}) || $APP->isEditor($USER)) );

  my $publishAs = $query -> param('publishas');
  if ($publishAs){
    if(my $reason = htmlcode('nopublishreason', $USER))
    {
      Everything::printLog("$USER->{title} could not publish a writeup as '$publishAs' because: '$reason'");
      return;
    }
    if(htmlcode('canpublishas', $publishAs) != 1)
    {
      Everything::printLog("$USER->{title} could not publish a writeup as '$publishAs' because they do not have permission to publish as that user");
      return
    }

    $publishAs = getNode($publishAs, 'user');
  }

  if ($e2node =~ /\D/){
    # not a node_id: new node
    my $title = $APP->cleanNodeName(scalar $query->param('title'));
    return unless $title;
    $query -> param('e2node_createdby_user', $$publishAs{node_id}) if $publishAs;
    $e2node = $DB -> insertNode($title, 'e2node', $USER);
    $query -> param('writeup_parent_e2node', $e2node);
  }

  # Modify the current global here
  $NODE = getNodeById($e2node);
  return unless $NODE and $$NODE{type}{title} eq 'e2node';

  return if htmlcode('nopublishreason', $publishAs || $USER, $NODE);

  my $wu = $$draft{node_id};

  return unless $DB->sqlUpdate('node, draft', {
    type_nodetype => getType('writeup') -> {node_id},
    publication_status => 0
    },
    "node_id=$wu AND draft_id=$wu"
  );

  # remove any old attachment:
  my $linktype = getId(getNode('parent_node', 'linktype'));
  $DB->sqlDelete('links', "from_node=$$draft{node_id} AND linktype=$linktype");

  $DB->sqlInsert('writeup', {
    writeup_id => $wu,
    parent_e2node => $e2node,
    cooled => $DB->sqlSelect('count(*)', 'coolwriteups', "coolwriteups_id=$wu"),
    notnew => $query -> param('writeup_notnew') || 0
  });

  $DB->sqlUpdate('hits', {hits => 0}, "node_id=$wu");

  $DB->{cache}->incrementGlobalVersion($draft); # tell other processes this has changed...
  $DB->{cache}->removeNode($draft); # and it's in the wrong typecache, so remove it

  # if it has a history, note publication
  htmlcode('addNodenote', $wu, 'Published') if $DB->sqlSelect('nodenote_id', 'nodenote', "nodenote_nodeid=$wu and noter_user=0");

  getRef $wu;
  $query->param('node_id', $e2node);

  $$wu{author_user} = getId($publishAs) if $publishAs;
  return htmlcode('publishwriteup', $wu, $NODE);
}

# bookmark opcode REMOVED - superseded by Everything::API::cool (toggle_bookmark, BookmarkButton, React-wired), brought to notification parity in #4292; op= dispatch is dead. Jun 2026.

# vote opcode REMOVED - superseded by Everything::API::vote (cast_vote); op= dispatch is dead. Jun 2026.

# bless opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

# curse opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

# bestow opcode REMOVED - superseded by Everything::API::superbless (AdminBestowTool, React-wired); op= dispatch is dead. Jun 2026.

sub message
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);

  my $for_user = $query->param('sendto');
  my $message = $query->param('message');
  my $userid = undef; $userid = getId($USER)||0;
  my $isRoot = $APP->isAdmin($USER);
  my $isChanop = $APP->isChanop($USER, "nogods");

  foreach($query->param)
  {
    if($_ =~ /^deletemsg\_(\d+)$/)
    {
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot || ($userid==$$MSG{for_user});
      $DB->sqlDelete('message', "message_id=$$MSG{message_id}");
    } elsif($_ =~ /^archive\_(\d+)$/) {
      #NPB FIXME Perl Monks is better
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($userid==$$MSG{for_user});
      my $realTime = $$MSG{tstamp};
      $DB->sqlUpdate('message', {archive=>1, tstamp=>$realTime}, 'message_id='.$$MSG{message_id});
    } elsif($_ =~ /^unarchive\_(\d+)$/) {
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($userid==$$MSG{for_user});
      my $realTime = $$MSG{tstamp};
      $DB->sqlUpdate('message', {archive=>0, tstamp=>$realTime}, 'message_id='.$$MSG{message_id});
    }
  }

  # Check if borged or 'everyone' user
  return if $$VARS{borged} or ($$USER{title} eq 'everyone');

  # Check for unverified email suspension (blocks public chatter)
  my $unverified_email_type = getNode('unverified email', 'sustype');
  if ($unverified_email_type && $for_user==0) {
    my $sushash = $DB->sqlSelectHashref("suspension_sustype", "suspension",
      "suspension_user=$$USER{node_id} and suspension_sustype=".getId($unverified_email_type));
    return if $$sushash{suspension_sustype};
  }

  # Validate message
  $message = '' if not defined $message;
  $message =~ s/^\s+|\s+$//g;
  return if $message eq '';

  # Admin/chanop-specific commands (handled directly in opcode)
  # These remain here because they require direct UI feedback via $query->param
  if( ($isRoot || $isChanop) and $message =~ /^\/drag\s+(\S+)$/i) {
    my $dragTarget = $1;
    my $dragUser = getNode($dragTarget, "user");
    if(!$dragUser)
    {
      $dragTarget =~ s/_/ /gs;
      $dragUser = getNode($dragTarget, "user");
    }

    if(!$dragUser)
    {
      $DB->sqlInsert('message', {
        msgtext => "Could not find user to drag: '$dragTarget'",
        author_user => (getNode("root","user")->{node_id}),
        for_user => $USER->{node_id}
      });

      return;
    }

    my $room = $USER->{in_room};
    my $roomtitle = "outside";

    if($room != 0)
    {
       $room = $DB->getNodeById($room);
       $roomtitle = "into $room->{title}";
    }

    my $EDB = getNode("EDB", "user");
    $APP->changeRoom($dragUser,$USER->{in_room}, "force");
    $APP->suspendUser($dragUser,"changeroom",$USER,60*5); # 5 minutes
    $DB->sqlInsert('message', {
      msgtext => "You have been dragged $roomtitle for five minutes",
      for_user => $dragUser->{node_id},
      author_user => $EDB->{node_id}
    });

  } elsif( ($isRoot || $isChanop) and $message =~ /^\/fakeborg\s+(.*)$/i) {
    my $fakeTarget = $1;
    return unless length($fakeTarget);

    $message = '/me has swallowed ['.$fakeTarget.']. ';

    # FIXME: should be a local sub
    my @EDBURSTS = (
      '*BURP*',
      'Mmmm...',
      '['.$fakeTarget.'] is good food!',
      '['.$fakeTarget.'] was tasty!',
      'keep \'em coming!',
      '['.$fakeTarget.'] yummy! More!',
      '[EDB] needed that!',
      '*GULP*','moist noder flesh',
      '*B R A P *',);
    $message .= $EDBURSTS[int(rand(@EDBURSTS))];

    my $BORG = getNode('EDB', 'user');

    $DB->sqlInsert('message', {
      msgtext => $message,
      author_user => (getId($BORG) || 0),
      for_user => 0,
      room => $$USER{in_room} });

  } elsif($isChanop  and $message =~ /^\/borg\s+(\S*)/i) {
    my $user = $1;
    my $reason = undef;
    if($message =~ /^\/borg\s+\S+\s+(.+?)$/i)
    {
      $reason = $1;
    }
    my $BORG = getNode('EDB', 'user');
    my $U = getNode($user, 'user');
    $user =~ s/\_/ /gs;
    $U = getNode($user, 'user') unless $U;

    unless($U)
    {
      $DB->sqlInsert('message', {msgtext => "Can't borg 'em, $user doesn't exist on this system!", author_user => getId($BORG), for_user =>getId($USER) });
      return;
    }

    $user = $$U{title}; # ensure proper case

    #added 2008-08-12 - borgings now let borgee know who borged them
    my $sendMessage = '[' . $$USER{title} . '] instructed me to eat you';
    if($reason)
    {
      $sendMessage = $sendMessage . ': '.$reason;
    }

    $DB->sqlInsert('message', {msgtext => $sendMessage, author_user => getId($BORG), for_user =>getId($U) });
    $sendMessage = 'you instructed me to eat [' . $user . '] ('.getId($U).')';
    if($reason)
    {
      $sendMessage = $sendMessage . ': '.$reason;
    }

    $DB->sqlInsert('message', {msgtext => $sendMessage, author_user => getId($BORG), for_user => $userid });

    # update user stats
    my $V = getVars($U);

    ++$$V{numborged};
    $$V{borged} = time;
    setVars($U, $V);
    $DB->sqlUpdate('room', {borgd => '1'}, 'member_user='.getId($U));

    htmlcode('addNotification', 'chanop borged user', 0, {
      chanop_id => $USER->{node_id},
      user_id => $U->{node_id} });

    # as of 2008-08-12, not showing messages in public area
    return;

    ## display message in chatterbox
    #my $message = "/me has swallowed [$user]. ";

    #my @EDBURSTS = (
    #  '*BURP*', 'Mmmm...', "[$user] is good food!",
    #  "[$user] was tasty!", 'keep \'em coming!',
    #  "[$user] yummy! More!", '[EDB] needed that!',
    #  '*GULP*','moist noder flesh', '*B R A P *' );

    # $message .= $EDBURSTS[int(rand(@EDBURSTS))];

    # $DB->sqlInsert('message', {
    #  msgtext => $message,
    #  author_user => getId($BORG),
    #  for_user => 0,
    #  room => $$USER{in_room} });

    # return;

  } elsif(($isRoot or $isChanop) and $message=~/^\/topic\s+(.*)$/i) {

    $message = $1;

    my $settingsnode = getNodeById(1149799); #More hard-coded goodness for speed.
    my $topics = getVars($settingsnode);

    $$topics{$$USER{in_room}} = $message;

    setVars($settingsnode, $topics);

    # Log topic changes -- the gift shop is the official "topic change location"
    $message = $APP->encodeHTML($message);
    my $msgOp = getNode('E2 Gift Shop', 'superdoc');
    my $room = getNodeById($$USER{in_room});
    my $roomName = $$USER{in_room} == 0 ? "outside" : ($room ? $$room{title} : "missing room ($$USER{in_room})");
    $APP->securityLog(SECLOG_GIFTSHOP_TOPIC, $USER, "\[$$USER{title}\[user\]\] changed $roomName topic to '$message'");

  } elsif( ($isRoot || $isChanop) and $message=~ /^\/sayas\s+(\S*)\s+(.*)$/si) {

    $message = $2;
    my $fromuser = lc($1);
    my $fromref = undef;

    if($fromuser eq 'webster')
    {
      $fromref = getNode('Webster 1913', 'user');
    } elsif($fromuser eq 'edb') {
      $fromref = getNode('EDB', 'user');
    } elsif($fromuser eq 'klaproth') {
      $fromref = getNode('Klaproth', 'user');
    } elsif($fromuser eq 'eddie') {
      $fromref = getNode('Cool Man Eddie', 'user');
    } elsif($fromuser eq 'bear') {
      $fromref = getNode('Giant Teddy Bear', 'user');
    } elsif($fromuser eq 'virgil') {
      $fromref = getNode('Virgil', 'user');
    } elsif(($fromuser eq 'guest') || ($fromuser eq 'gu')) {
      $fromref = getNode('Guest User', 'user');
    }

    if($fromref)
    {
      $DB->sqlInsert('message', {msgtext => $message , author_user => getId($fromref), for_user => 0, room => $$USER{in_room}});
    } else {
      $DB->sqlInsert('message', {msgtext => 'To sayas, you need to give me a user, choices are: EDB, eddie, virgil, Bear, Klaproth, or Webster', author_user => getId(getNode('root', 'user')), for_user => getId($USER), room => $$USER{in_room}});
    }

  } elsif($message=~/^\/chatteroff/i) {
    $$VARS{publicchatteroff}=1;
  } elsif($message=~/^\/chatteron/i) {
    delete $$VARS{publicchatteroff};
  } elsif($message =~ /^\/macro\s+(.*?)$/i) {
    $message = $1;
    my $rootID = getId(getNode('root','user'));
    if( $APP->isEditor($USER) )
    {
      if($message =~ /^(\S+)\s+(.+?)$/)
      {
        $message = $1;
        $$VARS{'chatmacro'}=$2;
      } else {
        delete $$VARS{'chatmacro'};
      }

      htmlcode('doChatMacro', $message);
      undef $message;
      delete $$VARS{'chatmacro'};
    } else {
      $message = 'Sorry, you aren\'t allowed to use macros yet. You tried to run: '.$message;
    }

    $DB->sqlInsert('message', {msgtext => $message, author_user => $rootID, for_user => $userid }) if $message;

  } elsif($message =~ /^\/(ignore|unignore)(\s+.*)?$/i) {
    # ignore user via IRC command added 2007 March 11
    my $which = $1;
    $message = $2;
    if($message =~ /\s+(.+)/)
    {
      $message = $1;
      if($which eq 'unignore')
      {
        $message = htmlcode('unignoreUser', $message);
      } elsif($which eq 'ignore') {
        $message = htmlcode('ignoreUser', $message);
      } else {
        $message = 'Unrecognized command: "'.$message.'".';
      }
    } else {
      $message = 'You must specify a user.';
    }

    $query->param('sentmessage', $message) if length($message);

  } else {
    # Route all other messages through centralized command processor
    # This handles: /me, /roll, /msg, /fireball, /sanctify, /invite, easter eggs, and plain chatter
    my $result = $APP->processMessageCommand($USER, $message, $VARS);

    # Note: processMessageCommand() returns 1 on success, undef on failure
    # UI feedback is minimal since most commands provide visual confirmation via React Chatterbox
  }

  return;
}

sub message_outbox
{
  # Standard vars for the opcode processing
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # Guests aren't allowed to perform message_outbox actions
  return if $APP->isGuest($USER);

  my $userid      = undef; $userid = getId($USER)||0;
  my $isRoot   = undef; $isRoot = $APP->isAdmin($USER);
  my $MSG      = undef; # Populated below with outbox message loaded from the DB by id

  foreach($query->param)
  {
    if($_ =~ /^deletemsg\_(\d+)$/)
    {

      # Delete a message given param named : deletemsg_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot || ($userid==$$MSG{author_user});
      $DB->sqlDelete('message_outbox', "message_id=$$MSG{message_id}");

    } elsif($_ =~ /^archive\_(\d+)$/) {

      # Archive a message given param named : archive_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($userid==$$MSG{author_user});
      $DB->sqlUpdate('message_outbox', {archive=>1, tstamp=>$$MSG{tstamp}}, 'message_id='.$$MSG{message_id});

    } elsif($_ =~ /^unarchive\_(\d+)$/) {

      # Un-archive a message given param named : unarchive_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($userid==$$MSG{author_user});
      $DB->sqlUpdate('message_outbox', {archive=>0, tstamp=>$$MSG{tstamp}}, 'message_id='.$$MSG{message_id});
    }
  }

  return; 
}


# cool opcode REMOVED - superseded by Everything::API::cool (award_cool); op= dispatch is dead. Jun 2026.

# weblog opcode REMOVED - superseded by Everything::API::weblog (add_entry/remove_entry, AddToWeblogModal, React-wired); op= dispatch is dead. Jun 2026.

sub removeweblog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # This removes one item from a weblog
  my $src = int($query->param('source'));
  my $to_node = int($query->param('to_node'));

  # usergroup owner
  my $isOwner = 0;
  $isOwner = 1 if $USER->{node_id} == $APP->getParameter($src, 'usergroup_owner');

  my $canRemove = $DB->isGod($USER) || $isOwner || $DB->sqlSelect( 'weblog_id' , 'weblog' ,
    'weblog_id=' . $DB->quote($src) . ' AND to_node=' . $DB->quote($to_node) .
    ' AND linkedby_user=' . $DB->quote($USER->{user_id}) );

  return unless $canRemove;
  return unless $src && $to_node ;

  my $sth = $DB->getDatabaseHandle()->prepare(
    'UPDATE weblog SET removedby_user=? WHERE weblog_id=? AND to_node=?'
  );
  $sth->execute($USER->{user_id}, $src, $to_node);

  return;
}

# There are still references to this in the javascript that need to get cleaned out
#
# massacre opcode REMOVED - dead stub (0 op= dispatch); no longer a securityLog token (caller uses SECLOG_MASSACRE). #4299. Jun 2026.

sub lockroom
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  return unless isGod($USER);

  my $R = $$USER{in_room};
  return if $R == 0;

  getRef($R);

  my $denystr = "0\;";
  unless ($$R{criteria} eq $denystr)
  {
    $$R{criteria} = $denystr;
  } else {
    $$R{criteria} = "1\;";
  }
  updateNode($R, $USER);
  return;
}

# resurrect opcode REMOVED - superseded by Everything::API::resurrect; op= dispatch is dead. Jun 2026.

# NOTE: bucketop and addbucket opcodes removed 2025-11-30
# The nodebucket VARS key is deprecated - see docs/user-vars-reference.md

# linktrim opcode REMOVED - superseded by Everything::API::e2node (remove_firmlink/manage_softlinks, E2NodeToolsModal). #4303. Jun 2026.

# firmlink opcode REMOVED - superseded by Everything::API::e2node (create_firmlink, E2NodeToolsModal). #4303. Jun 2026.

# insure opcode REMOVED - superseded by Everything::API::admin (insure_writeup, UserToolsModal/AdminModal). #4303. Jun 2026.

# nodenote opcode REMOVED - superseded by Everything::API::nodenotes (React-wired); op= dispatch is dead. Jun 2026.

# lockaccount opcode REMOVED - superseded by Everything::API::admin (lock_user, UserToolsModal). #4303. Jun 2026.

# unlockaccount opcode REMOVED - superseded by Everything::API::admin (unlock_user, UserToolsModal). #4303. Jun 2026.

# hidewriteup opcode REMOVED - superseded by Everything::API::hidewriteups (React-wired); op= dispatch is dead. Jun 2026.

# unhidewriteup opcode REMOVED - superseded by Everything::API::hidewriteups (React-wired); op= dispatch is dead. Jun 2026.

# changewucount opcode REMOVED - superseded by Everything::API::preferences (nw_nojunk + nodelet settings, Settings.js). #4303. Jun 2026.

# repair_e2node opcode REMOVED - superseded by Everything::API::e2node (repair_node, E2NodeToolsModal). #4303. Jun 2026.

# borg opcode REMOVED - superseded by Everything::API::admin user borg (UserToolsModal). #4303. Jun 2026.

sub flushcbox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  return unless $APP->isChanop($USER); # Specifically include gods
  my $currentRoomId = int($$USER{in_room});
  my $currentRoom = getNode($currentRoomId);
  my $currentRoomName = undef;
  if (!$currentRoom && $currentRoomId)
  {
    $currentRoomName = "in expired room (#$currentRoomId)";
  } elsif (!$currentRoom) {
    $currentRoomName = "outside";
  } else {
    $currentRoomName = "in room '$$currentRoom{title}'";
  }

  $APP->securityLog(SECLOG_CATBOX_FLUSH, $USER, "Chat $currentRoomName flushed.");
  $DB->sqlDelete("message", "for_user = 0 AND room = $currentRoomId");
  return 1;
}

# repair_e2node_noreorder opcode REMOVED - superseded by Everything::API::e2node (repair_node no-reorder). #4303. Jun 2026.

# orderlock opcode REMOVED - superseded by Everything::API::e2node (toggle_orderlock, E2NodeToolsModal). #4303. Jun 2026.

# pollvote opcode REMOVED - superseded by Everything::API::poll submit_vote (CurrentUserPoll, React-wired); op= dispatch is dead. Jun 2026.

# softlock opcode REMOVED - superseded by Everything::API::e2node (node_lock). #4303. Jun 2026.

# weblogify opcode REMOVED - superseded by Everything::API::usergroups (weblogify action, Usergroup.js, React-wired); op= dispatch is dead. Jun 2026.

# leadusergroup opcode REMOVED - superseded by Everything::API::usergroups (transfer_ownership action, UsergroupEditor.js/Usergroup.js, React-wired). #4299. Jun 2026.

# ilikeit opcode REMOVED - superseded by Everything::API::ilikeit (React-wired); op= dispatch is dead. Jun 2026.

sub changeusergroup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # Changes which usergroup is selected for the Usergroup Writeups nodelet.

  if($query->param('newusergroup'))
  {
    my $newUsergroup = $query->param('newusergroup');
    $$VARS{nodeletusergroup}=$newUsergroup;
  }

  return 1;
}

# favorite opcode REMOVED - superseded by Everything::API::favorites (React-wired); op= dispatch is dead. Jun 2026.

# unfavorite opcode REMOVED - superseded by Everything::API::favorites (React-wired); op= dispatch is dead. Jun 2026.

# category opcode REMOVED - superseded by Everything::API::category (add_member/remove_member, AddToCategoryModal, React-wired); op= dispatch is dead. Jun 2026.

sub socialBookmark
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my $node_id = $query->param('node_id');
  my $bookmark_site = $query->param('bookmark_site');

  $node_id or return;
  $bookmark_site or return;

  return if $APP->isGuest($USER);
  return 1 if $$VARS{no_socialbookmarkinformer};

  my $tempnode = getNodeById($node_id);
  return 1 if (($$tempnode{type}{title} ne "writeup") && ($$tempnode{type}{title} ne "e2node")); #only send CME for writeups & e2nodes

  my $eddie = getId(getNode('Cool Man Eddie','user'));
  my @tempgroup = (); @tempgroup = @{ $$tempnode{group} } if $$tempnode{group};
  my @group;
  my $TV;
  foreach (@tempgroup)
  {
    my $not_self_user = ($_ != getId($USER));
    $TV = getVars(getNodeById($_)->{author_user});
    if ((!$$TV{no_socialbookmarknotification})&&($not_self_user))
    {
      push @group, $_;
    }
  }

  my $nt = $$tempnode{title};
  my ($eddiemessage, $str,$auth);
  my @writeupAuthors = ();

  if(scalar(@group))
  {
    @writeupAuthors = map { getNodeById($_)->{author_user} } @group;
    $eddiemessage = 'the entire node ['.$nt.'], in which you have a writeup,';
  } else {
    $TV = getVars(getNodeById($$tempnode{author_user}));
    if ($$TV{no_bookmarknotification})
    {
      return 1;
    }

    if (getId($USER) == $$tempnode{author_user})
    {
      return 1;
    }

    push @writeupAuthors, $$tempnode{author_user};
    $eddiemessage ='your writeup ['.$nt.']';
  }

  my $notification = getNode("socialBookmark","notification")->{node_id};
  foreach (@writeupAuthors)
  {
    my $authorVars = getVars(getNodeById($_));
    if ($$authorVars{settings})
    {
      if ( from_json($$authorVars{settings})->{notifications}->{$notification})
      {
        my $argSet = { writeup_id => $$tempnode{node_id}, bookmark_user => $$USER{user_id}, bookmark_site => $bookmark_site};
        my $argStr = to_json($argSet);
        my $addNotifier = htmlcode('addNotification', $notification, $_, $argStr);
      }
    }
  }

  my $sendResult = htmlcode('sendPrivateMessage',{
    'author_id' => $eddie,
    'recipient_id' => \@writeupAuthors,
    'message' => 'Yo, '.$eddiemessage.' was bookmarked on '.$bookmark_site.'. Dig it, baby.',
    'fromgroup_id' => $$USER{node_id} });

  return 1;
}

# sanctify opcode REMOVED - superseded by Everything::API::sanctify; op= dispatch is dead. Jun 2026.

# cure_infection opcode REMOVED - superseded by Everything::API::user (cure_infection, POST /api/user/cure). Infection FEATURE stays live; only the dead opcode removed. #4303. Jun 2026.

sub publishdrafttodocument
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my $TYPE = getType('document');
  return unless canCreateNode($USER, $TYPE);

  my $nid = $query -> param('node_id');
  my $draft = getNodeById($nid);
  return unless $draft && $$draft{type}{title} eq 'draft';

  return if getNode($$draft{title}, 'document');

  $DB -> sqlUpdate('node', {
    type_nodetype => $$TYPE{node_id}
    , -createtime => 'now()'
    , hits => 0 }, "node_id=$nid");
  $DB -> sqlDelete('draft', "draft_id=$nid");
  $DB -> {cache} -> incrementGlobalVersion($draft); # tell other processes this has changed...
  $DB -> {cache} -> removeNode($draft); # and it's in the wrong typecache, so remove it

  $query->delete('node');
  $query->param('node_id', $nid);

  return;
}

sub approve_draft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $draft = $query -> param('draft');
  my $e2node = $query -> param('e2node');
  my $previousEditor = $query -> param('revoke');

  my $food = $previousEditor ? 0 : $$USER{node_id};

  my $linktype = getId(getNode('parent_node', 'linktype'));
  my $success = $DB -> sqlUpdate( # editor approval flagged by feeding the link
    'links', {food => $food},
    "from_node=$draft AND to_node=$e2node AND linktype=$linktype");

  return;
}

# parameter opcode REMOVED - superseded by Everything::API::node_parameter (NodeParameterEditor, React-wired); op= dispatch is dead. Jun 2026.

sub remove
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  if (my $wu = $query->param('writeup_id'))
  {
    # user removing own writeup
    return unless htmlcode('verifyRequest', 'remove') && getRef($wu) && $$wu{author_user} == $$USER{node_id}
      && htmlcode('unpublishwriteup', $wu);

    return $APP->updateNewWriteups();
  }

  return unless $APP->isEditor($USER);

  my @list = ();
  my $bulkreason = $query -> param('removereason');
  my $author='';

  unless ($query -> param('removeauthor'))
  {
    foreach ($query->param)
    {
      next unless /^removenode(\d+)$/;
      push @list, $1;
    }
  }else{
    $author = getNode($query->param('author'), 'user');
    return unless $author;
    @list = @{$DB->selectNodeWhere({author_user => $$author{node_id}}, 'writeup')};
    htmlcode('sendPrivateMessage', {
      message => "I am removing your writeups: $bulkreason.",
      recipient_id=>$$author{user_id}});
  }

  return unless @list;

  foreach my $nid (@list)
  {
    my $N = getNodeById $nid;
    next unless $N && $$N{type}{title} eq 'writeup';
    next if $$N{publication_status}; # insured

    my $reason = $bulkreason || $query->param('removereason'.$nid);
    $reason = '' if $reason eq 'none';
    next unless htmlcode('unpublishwriteup', $N, $reason);

    next if $author; # removing all writeups: no individual notifications

    # notify author:
    my $aid = $$N{author_user};
    next unless $aid;	#skip /msg if no WU author
    my $parent = getNodeById($$N{parent_e2node});
    my $title = undef; $title = $$parent{title} if $parent;
    $title ||= $$N{title};

    next if $aid==$$USER{node_id} && $query->param('noklapmsg'.$nid);	#no /msg to self
    next if getVars($aid) -> {no_notify_kill}; # author doesn't want msg

    unless ($reason)
    {
      # no msg for maintenance stuff, unless there is a reason
      next if $APP->isMaintenanceNode($N);
    }

    $reason = ": $reason" if $reason;
    my $writeup_author = getNodeById($aid);
    $writeup_author = "[by $$writeup_author{title}]" if $writeup_author;
    $writeup_author = "" unless defined($writeup_author);
    htmlcode('sendPrivateMessage', {
      message => "I removed your writeup [$title$writeup_author]$reason. It has been sent to your [Drafts[superdoc]].",
      recipient_id=>$aid});
  }

  $APP->updateNewWriteups();
  return;
}

1;
