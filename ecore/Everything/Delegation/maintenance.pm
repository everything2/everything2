package Everything::Delegation::maintenance;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *htmlcode = *Everything::HTML::htmlcode;
} 

# Used by writeup_create, debatecomment_create, debate_create
use JSON;

sub room_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;

  my $canCreate = ($APP->getLevel($USER) >= $Everything::CONF->create_room_level or $DB->isGod($USER));
  $canCreate = 0 if $APP->isSuspended($USER, 'room');

  if (!$canCreate) {
    $DB->nukeNode($N, -1);
    return;
  }

  $DB->getRef($N);
  $$N{criteria} = "1;";
  $$N{author_user} = getId(getNode('gods', 'usergroup'));
  $DB->updateNode($N, -1);
  return;
}

sub dbtable_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This gets called for each new dbtable node.  We
  # want to create the associated table here.
  my ($thisnode) = @_;

  $DB->getRef($thisnode);
  $DB->createNodeTable($thisnode->{title});
  return;
}

sub dbtable_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  # This gets called each time a dbtable node gets deleted.
  # We want to delete the associated table here.
  my ($thisnode) = @_;

  $DB->getRef($thisnode);
  $DB->dropNodeTable($$thisnode{title});
  return;
}

sub writeup_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP) = @_;
  $DB->getRef($WRITEUP);

  # This is an odd consession for the time being so that maintenance functions can properly
  # bomb out if there isn't a CGI object in place
  return unless $query;

  my $E2NODE = $query->param('writeup_parent_e2node');
  $DB->getRef($E2NODE);

  # we need an e2node to insert the writeup into,
  # and the writeup must have some text:
  my $problem = (not $E2NODE or $query->param("writeup_doctext") eq '');

  # the user must be allowed to publish, the node must not be locked,
  # and the user must not have a writeup there already:
  $problem ||= htmlcode('nopublishreason', $USER, $E2NODE);

  # if no problem, attach writeup to node:
  return htmlcode('publishwriteup', $WRITEUP, $E2NODE) unless $problem;

  # otherwise, we don't want it:
  $DB->nukeNode($WRITEUP, -1, 1);

  return unless UNIVERSAL::isa($problem,'HASH');

  # user already has a writeup in this E2node: update it
  $$problem{doctext} = $query->param("writeup_doctext");
  $$problem{wrtype_writeuptype} = $query -> param('writeup_wrtype_writeuptype') if $query -> param('writeup_wrtype_writeuptype');
  $DB->updateNode($problem, $USER);

  # redirect to the updated writeup
  $Everything::HTML::HEADER_PARAMS{-status} = 303;
  $Everything::HTML::HEADER_PARAMS{-location} = htmlcode('urlToNode', $problem);

  return;
}

sub e2node_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($E2NODE) = @_;
  $DB->getRef($E2NODE);

  $$E2NODE{createdby_user} = $$E2NODE{author_user} || $DB->getId($USER);
  $$E2NODE{author_user} = $DB->getId($DB->getNode('Content Editors', 'usergroup')); # Content Editors can update it; author can't

  $DB->updateNode($E2NODE, -1);
  return;
}

sub e2node_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($E2NODE) = @_;
  $DB->getRef($E2NODE);

  my $CE = $DB->getId($DB->getNode('Content Editors', 'usergroup'));

  if ($$E2NODE{author_user} != $CE) {
    $$E2NODE{createdby_user} = $$E2NODE{author_user};
    $$E2NODE{author_user} = $CE; # Content Editors can update node, creator cannot
    $DB->updateNode($E2NODE, -1);
  }

  $APP->repairE2Node($E2NODE, "no reorder");

  return;
}

sub writeup_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP) = @_;
  $DB->getRef($WRITEUP);
  return unless $WRITEUP;
  my $E2NODE = $DB->getNodeById($$WRITEUP{parent_e2node});

  return unless $E2NODE;

  # avoid duplicate draft/writeup titles
  foreach ($DB->getNodeWhere({ # should be at most one, but if not, we fix that, too:
    title => $$E2NODE{title}, author_user => $$WRITEUP{author_user}}, 'draft')){
      $DB->updateNode($_, -1);
  }

  $DB->{cache}->incrementGlobalVersion($E2NODE);

  # only check query parameters if user is actually editing this writeup
  # -- we can also come here if they are publishing a different writeup in this writeup's parent e2node
  # Also, if run as a script, we don't have $query
  my $param_node_id = $query ? $query->param('node_id') : undef;
  if($query && defined($param_node_id) && $param_node_id == $$WRITEUP{node_id})
  {
    # Make a notification if someone's about to blank a writeup
    if(defined($query->param('writeup_doctext')))
    {
      my $trimmedNewText = $query->param('writeup_doctext');
      $trimmedNewText =~ s/^\s+|\s$//;

      return htmlcode('unpublishwriteup', $WRITEUP, 'blanked') unless $trimmedNewText;

      htmlcode('addNotification', 'blankedwriteup', 0, {
        writeup_id => getId($WRITEUP)
        , author_id => $$USER{user_id}
      }) if length $trimmedNewText < 20;
    }

    $APP->updateNewWriteups() unless($query->param('op') and $query->param('op') eq 'vote' or $query -> param('op') eq 'cool');

    if($query->param('writeup_wrtype_writeuptype'))
    {
      my $WRTYPE=getNode($$WRITEUP{wrtype_writeuptype});
      if ($$WRTYPE{type}{title} ne 'writeuptype' or 
        (($$WRTYPE{title} eq 'definition' or $$WRTYPE{title} eq 'lede') and
        not Everything::isApproved($USER, getNode('Content Editors','usergroup'))
        and $$USER{title} ne 'Webster 1913'
        and $$USER{title} ne 'Virgil'))
      {
        $WRTYPE=getNode('thing','writeuptype'); 
        $$WRITEUP{wrtype_writeuptype} = getId($WRTYPE);
      }
      my $title = "$$E2NODE{title} ($$WRTYPE{title})";
      return if $$WRITEUP{title} eq $title;
      #only YOU can prevent deep recursion...

      $APP->repairE2Node($E2NODE);

      $$WRITEUP{title} = $title;
      $DB->updateNode($WRITEUP, -1);
    }

  }

  return;
}

sub e2node_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;

  $DB->getRef($N);
  my $group = $$N{group};

  return unless $group;

  foreach(@$group) {
    htmlcode('unpublishwriteup', getId($_), 'parent node deleted');
  }
  return;
}

sub debate_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;
  $DB->getRef($N);

  return unless $DB->canDeleteNode( $USER, $N );
  my $GROUP = $$N{ 'group' };

  if ( $GROUP ) {
    foreach my $item ( @$GROUP ) {
      my $child = $DB->getNodeById( $item );
      $DB->nukeNode( $child, $USER );
    }
  }

  return;
}

sub writeup_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

# although writeups should not be nuked, the opcode is still there, and gods may
# use it. So to avoid writeups getting nuked, we turn them into drafts first.
# (Then the draft gets nuked. )

  htmlcode('unpublishwriteup', $_[0], '(nuked)');

  return;
}

sub debatecomment_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $COMMENT ) = @_;
  $DB->getRef( $COMMENT );

  # A comment must be inserted in its parent's group, and its 
  # parent_debatecomment and root_debatecomment fields 
  # must be initialized correctly.   

  my $PARENT = $query->param( "debatecomment_parent_debatecomment" );
  $DB->getRef( $PARENT );

  unless($PARENT) {
    $DB->nukeNode( $COMMENT, $USER );
    return;
  }

  # START if($PARENT)

  #TODO somehow: let child be more restrictive than parent
  my $restrict = $$PARENT{restricted} || 0;
  if($restrict==0) {
    $restrict=923653;	#CE hack
  } elsif($restrict==1) {
    $restrict=114;	#admin hack
  }

  my $restrictNode = getNodeById($restrict);
  unless($restrictNode)
  {
    #ack! no group permission somehow!
    $DB->nukeNode($COMMENT, -1);
    return;
  }

  unless(Everything::isApproved($USER, $restrictNode) || $APP->inUsergroup($USER,$restrictNode) )
  {
    #not allowed to view parent, so can't post child
    $DB->nukeNode($COMMENT, -1);
    return;
  }
  $$COMMENT{restricted}=$restrict;

  # my $title = $$PARENT{ 'title' };
  # $title = 're: ' . $title unless ( $title =~ /^re:/ );
  # $$COMMENT{ 'title' } = $title;
  $$COMMENT{ 'parent_debatecomment' } = $PARENT->{node_id};

  my $root_debatecomment = $query->param( 'debatecomment_root_debatecomment' );
  $$COMMENT{ 'root_debatecomment' } = $root_debatecomment;

  my $parentOwner=$$PARENT{ 'author_user' };
  my $parentVars = getVars(getNodeById($parentOwner));
  my $replyer = getNodeById($$COMMENT{ 'author_user' }) -> {'title'};
  my $msg = "Attention, <a href=\"/user/$replyer\">$replyer</a> just replied to ";

  $msg .= '<a href="'. $APP->urlGenNoParams($root_debatecomment,1) .
    '#debatecomment_'.$$COMMENT{ 'node_id' }.'">'.$$PARENT{ 'title' }.'</a>.';

  unless ($$parentVars{"no_discussionreplynotify"} or $$COMMENT{ 'author_user' } == $$PARENT{ 'author_user'})
  {
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode("Virgil","user")),
      'recipient_id' => $parentOwner,
      'message' => $msg
      });
  }

  ## BEGIN notification code

  my $ug_id = $$COMMENT{ 'restricted' };

  #notify *all* usergroup members that we have a new reply
  my @uids = split ',', htmlcode('usergroupToUserIds',$ug_id);

  my $replyNotification = getNode("newcomment","notification") -> {node_id};
  foreach my $uid(@uids)
  {
    #Don't notify the creator.
    next if($uid == $$USER{node_id});

    my $v = getVars( getNodeById($uid));

    #This curiously named value of "settings" in the user's vars refers
    #*only* to the notifications settings.
    next unless $$v{settings};

    my %notifications = from_json($$v{settings})->{notifications};

    if($notifications{$replyNotification} )
    {
      my $notification_id = $replyNotification;
      my $user_id = $uid;
      my $argSet = {
        uid => $$USER{node_id},
        parent => $$PARENT{ 'node_id' },
        reply => $$COMMENT{ 'node_id' },
        root => $$COMMENT{ 'root_debatecomment' } };
    
      my $argStr = to_json($argSet);

      my $addNotifier = htmlcode('addNotification', $notification_id, $user_id, $argStr);

    }
  }

  ## END notification code


  $DB->updateNode( $COMMENT, $USER );

  $DB->insertIntoNodegroup( $PARENT, -1, [$COMMENT] );
  return;
}

sub debatecomment_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;
  $DB->getRef($N);

  return unless $DB->canDeleteNode( $USER, $N );

  my $GROUP = $$N{ 'group' };

  if($GROUP)
  {
    foreach my $item ( @$GROUP )
    {
      my $child = getNodeById( $item );
      $DB->nukeNode( $child, $USER );
    }
  }

  return;
}

sub debate_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $COMMENT ) = @_;
  $DB->getRef( $COMMENT );

  if ( $$COMMENT{ 'parent_debatecomment' } )
  {
    # If you want a child, use nodetype debatecomment instead.
    $DB->nukeNode( $COMMENT, $USER );
    return;
  }

  my $ug_id = $query->param("debatecomment_restricted");
  my $ug = getNodeById($ug_id);

  if ($$COMMENT{title} =~ /^\s*$/)
  {
    $$COMMENT{title} = "Untitled ". $$ug{title} ." discussion";
    $DB->updateNode( $COMMENT, $USER );
  }

  my $announce = $query -> param('announce_to_ug');
  my $notify_ug_id = $ug_id;

  #notify e2gods instead of gods
  $notify_ug_id = 829913 if $notify_ug_id == 114;

  if ($announce) {
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode("Virgil","user")),
      'recipient_id' => $notify_ug_id,
      'message' => 'Make it known, [' .
      $$USER{title} .
      '] just started a new discussion: [' .
      $$ug{title}.': '.$$COMMENT{title} . '].'
      });
  }

  #Have to notify each group member, unless they don't want to be notified
  my @uids = split ',', htmlcode('usergroupToUserIds',$notify_ug_id);

  my $discussionNotification = getNode("newdiscussion","notification")->{node_id};

  foreach my $uid(@uids)
  {
    #Don't notify the creator.
    next if($uid == $$USER{node_id});

    my $v = getVars( getNodeById($uid));

    #This curiously named value of "settings" in the user's vars refers
    #*only* to the notifications settings.
    next unless $$v{settings};

    my %notifications = %{from_json($$v{settings})->{notifications}};

    if( $notifications{$discussionNotification} )
    {
      my $argSet = {uid => $$USER{node_id}, 
        debate_id => $$COMMENT{ 'node_id' },
        gid => $ug_id};
      my $argStr = to_json($argSet);
      my $test = htmlcode('addNotification',$discussionNotification,
        $uid, $argStr);
    }
  }

  $$COMMENT{ 'root_debatecomment' } = $$COMMENT{ 'node_id' };

  #Since when creating we are taken immediately to the edit page, 
  #no need to screen the doctext. It'll be screened in the edit page.

  $$COMMENT{'doctext'} = $query -> param('newdebate_text');

  $DB->updateNode( $COMMENT, $USER );
  return;
}

sub e2poll_create
{
  # DEPRECATED: Poll creation is now handled by Everything::API::poll_creator
  # This maintenance function is hollowed out to prevent legacy CGI-based poll creation
  # All polls should be created through the modern React UI at /title/Everything%20Poll%20Creator
  # which uses the API endpoint /api/poll_creator/create
  #
  # Keeping this function as a no-op to avoid breaking any legacy code that might
  # still reference it, but it no longer performs any operations.
  return;
}

sub collaboration_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;
  $DB->getRef($N);
  return unless $N;

  $DB->{cache}->incrementGlobalVersion($N);
  my $WRTYPE=getNode($$N{wrtype_writeuptype});

  my $title = "$$N{title}";
  return if $$N{title} eq $title; 
  #only YOU can prevent deep recursion...

  $$N{title} = $title;
  $DB->updateNode($N, -1);
  return;
}

sub category_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($CATEGORY) = @_;
  $DB->getRef($CATEGORY);

  my $guestuserId= getId(getNode('guest user', 'user'));

  my $maintUserId = 0; $maintUserId = int($query->param("maintainer")) if $query;
  $maintUserId ||= $$USER{user_id};
  my $MAINTAINER = getNodeById($maintUserId);
  my $maintType = undef;
  $maintType = $$MAINTAINER{type}{title} if $MAINTAINER;

  # If an invalid maintainer is given, use the current user instead
  if ($maintType ne 'user' && $maintType ne 'usergroup')
  {
    $maintUserId = $$USER{user_id};
    $MAINTAINER = $USER;
    $maintType = 'user';
  }

  # if someone is trying to create a user-maintained node that doesn't
  # belong to the current or guest user, remove it
  if ($maintType eq 'user' && $$MAINTAINER{node_id} != $$USER{user_id} && $$MAINTAINER{node_id} != $guestuserId)
  {
    $DB->nukeNode($CATEGORY, -1, 1);
    return;
  }

  # if someone is trying to create a usergroup-maintained node, and the 
  # current user does not belong to that usergroup, remove it
  if ($maintType eq 'usergroup' && ! $APP->inUsergroup($USER, $MAINTAINER) )
  {
    $DB->nukeNode($CATEGORY, -1, 1);
    return;
  }

  $$CATEGORY{author_user} = $$MAINTAINER{node_id};
  $DB->updateNode($CATEGORY, -1);
  return;
}

sub node_forward_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($FORWARD) = @_;
  $DB->getRef($FORWARD);

  $$FORWARD{author_user} = getId(getNode('Content Editors', 'usergroup'));

  $DB->updateNode($FORWARD, -1);
  htmlcode('addNodenote', $FORWARD, "Created by [$$USER{title}\[user]]");
  return;
}

sub user_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($DELETED_USER) = @_;
  $DB->getRef($DELETED_USER);

  $APP->securityLog(getNode('The Old Hooked Pole', 'restricted_superdoc'), $USER, "Deleted user $$DELETED_USER{title} (node_id $$DELETED_USER{node_id})");

  # Remove user from room lists so [Other Users[nodelet]] doesn't bug out
  $DB->sqlDelete('room', "member_user = $$DELETED_USER{node_id}");
  return;
}

sub draft_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($D) = @_;
  $DB->getRef($D);

  if($query)
  {
    # make sure it has a publication status
    $$D{publication_status} = $query -> param('draft_publication_status');

    # if draft has just been created from an e2node
    # doctext parameter would be ignored because of wrong nodetype prefix
    $$D{doctext} = $query -> param('writeup_doctext') if $query -> param('writeup_doctext');
  }

  $$D{publication_status} ||= $DB->getNode('private', 'publication_status')->{node_id};

  $DB->updateNode($D, $USER);
  return;
}

sub draft_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;
  $DB->getRef($N);

  # validate new publication_status. Make 'private' if invalid.
  # notify editor(s) if status changed to review:
  if ($query && $query->param('draft_publication_status') &&
    defined($query->param('old_publication_status')) &&
    $query->param('old_publication_status') != $$N{publication_status})
  {
    my $status = getNodeById($$N{publication_status});

    unless ($status && $$status{type}{title} eq 'publication_status')
    {
      $$N{publication_status} = getId(getNode('private', 'publication_status'));
      return $DB->updateNode($N, $USER) if $$N{publication_status};

    }elsif($$status{title} eq 'review'){

      my $editor = $DB->sqlSelect(
        'nodelock_user'
        , 'nodelock'
        , "nodelock_node=$$N{author_user}"
      );

      $editor ||= $DB->sqlSelect(
        'suspendedby_user'
        , 'suspension'
        , "suspension_user=$$N{author_user}
        AND suspension_sustype=".getId(getNode('writeup', 'sustype'))
      );

      # record event in node history:
      my $note = ''; $note = ' (while suspended by '.$APP->linkNode($editor).') ' if $editor;
      my $nodenote_id = htmlcode('addNodenote', $$N{node_id}, "author requested review$note");

      # Notify. If no $editor, everyone gets it:
      htmlcode('addNotification', 'draft for review', $editor, {draft_id => $$N{node_id}, nodenote_id => $nodenote_id});

    }
  }

  # avoid empty names/duplicate names for writeups/drafts by same user:
  my $title = my $urTitle = $APP->cleanNodeName($$N{title}) || 'untitled draft';
  my $count = 1;

  while(
    $DB->sqlSelect(
      'node_id',
      'node',
      'title='.$DB->quote($title)
      ."AND type_nodetype=$$N{type_nodetype} AND author_user=$$N{author_user} AND node_id!=$$N{node_id}") or
    $DB->sqlSelect(
      'writeup_id',
      'node e2 JOIN writeup ON e2.node_id=parent_e2node JOIN node wu ON wu.node_id=writeup_id',
      'e2.title='.$DB->quote($title)."AND wu.author_user=$$N{author_user}")
  ){
    $title = "$urTitle ($count)";
    $count++;
  }

  return if $title eq $$N{title};

  $$N{title} = $title;
  $DB->updateNode($N, $USER);
  return;
}

sub draft_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # get rid of any votes and cools left over from a time as a writeup
  # record level-relevant info for old users who have not recalculated their XP

  my ($id) = @_;

  my $N = getNodeById($id);
  my @cache = (); @cache = $DB->sqlSelect('upvotes, cools',
    'xpHistoryCache', # xpHistoryCache for user is deleted once XP has been recalculated
    "xpHistoryCache_id=$$N{author_user}") if $$N{author_user} < 1960662; # magic number identifies October 29, 2008

  my $totalvotes = int($DB -> sqlDelete('vote', "vote_id=$N->{node_id}"));
  my $cools = int($DB -> sqlDelete('coolwriteups', "coolwriteups_id=$N->{node_id}"));

  return unless @cache;

  my $upvotes = ($totalvotes + $$N{reputation})/2;
  # ... if the voting history was lost in Node Heaven, improvise:
  $upvotes = $$N{reputation} if $totalvotes < $$N{reputation} || $upvotes != int($upvotes);

  return unless $upvotes || $cools;

  $upvotes += $cache[0];
  $cools += $cache[1];

  $DB->sqlUpdate('xpHistoryCache', {upvotes => $upvotes, cools => $cools}, "xpHistoryCache_id=$$N{author_user}");
  return;
}

sub node_forward_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($FORWARD) = @_;
  $DB->getRef($FORWARD);

  my $forwardTitle = $query->param("forward_to_node");
  $forwardTitle = $$FORWARD{doctext} if $$FORWARD{doctext} =~ /\D/;

  if ($forwardTitle)
  {
    my $forwardId = getId(getNode($forwardTitle, "e2node"));
    return unless $forwardId && $forwardId ne $$FORWARD{doctext}; # no infinite recursion, please, we're British.
    $$FORWARD{doctext} = $forwardId;
    $query->param('node_forward_doctext', $forwardId) if $query -> param('node_forward_doctext');
    $DB->updateNode($FORWARD, -1);
  }
  return;
}

sub podcast_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($PODCAST) = @_;
  $DB->getRef($PODCAST);

  $$PODCAST{createdby_user} = $$PODCAST{author_user} || getId($USER);
  $$PODCAST{author_user} = getId(getNode('podpeople', 'usergroup')); # so all podpeople can edit it

  $DB->updateNode($PODCAST, -1);
  return;
}

1;
