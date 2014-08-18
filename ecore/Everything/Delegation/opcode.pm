package Everything::Delegation::opcode;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

# TODO: use strict
# TODO: use warnings
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
  *listCode = *Everything::HTML::listCode;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *urlGen = *Everything::HTML::urlGen;
  *urlGenNoParams = *Everything::HTML::urlGenNoParams;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *breakTags = *Everything::HTML::breakTags;
  *screenTable = *Everything::HTML::screenTable;
  *encodeHTML = *Everything::HTML::encodeHTML;
  *cleanupHTML = *Everything::HTML::cleanupHTML;
  *getType = *Everything::HTML::getType;
  *htmlScreen = *Everything::HTML::htmlScreen;
  *updateNode = *Everything::HTML::updateNode;
  *rewriteCleanEscape = *Everything::HTML::rewriteCleanEscape;
  *setVars = *Everything::HTML::setVars;
  *cleanNodeName = *Everything::HTML::cleanNodeName;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *recordUserAction = *Everything::HTML::recordUserAction;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *confirmUser = *Everything::HTML::confirmUser;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *changeRoom = *Everything::HTML::changeRoom;
  *cloak = *Everything::HTML::cloak;
  *uncloak = *Everything::HTML::uncloak;
  *isMobile = *Everything::HTML::isMobile;
  *isSuspended = *Everything::HTML::isSuspended;
  *escapeAngleBrackets = *Everything::HTML::escapeAngleBrackets;
  *canReadNode = *Everything::HTML::canReadNode;
  *stripCode = *Everything::HTML::stripCode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *hasVoted = *Everything::HTML::hasVoted;
  *getHRLF = *Everything::HTML::getHRLF;
  *evalCode = *Everything::HTML::evalCode;
  *getCompiledCode = *Everything::HTML::getCompiledCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *castVote = *Everything::HTML::castVote;
} 

# Used by bookmark
use JSON;

sub publishdraft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  # turn a draft into a writeup and pass it on for insertion into an e2node

  my $e2node = $query -> param('writeup_parent_e2node');

  my $draft = $query -> param('draft_id');
  getRef $draft;

  return unless $draft and $$draft{doctext} and $$draft{type}{title} eq 'draft' and
    $$USER{node_id} == $$draft{author_user} || $APP->isEditor($USER);

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
    my $title = cleanNodeName($query -> param('title'));
    return unless $title;
    $query -> param('e2node_createdby_user', $$publishAs{node_id}) if $publishAs;
    $e2node = $DB -> insertNode($title, 'e2node', $USER);
    $query -> param('writeup_parent_e2node', $e2node);
  }

  # Modify the current global here
  $NODE = getNodeById($e2node);
  return unless $NODE and $$NODE{type}{title} eq 'e2node';

  return if htmlcode('nopublishreason', $publishAs || $USER, $thisnode);
	
  my $wu = $$draft{node_id};
	
  return unless $DB->sqlUpdate('node, draft', {
    type_nodetype => getType('writeup') -> {node_id},
    publication_status => 0
    },
    "node_id=$wu AND draft_id=$wu"
  );
	
  # remove any old attachment:
  my $linktype = getId(getNode 'parent_node', 'linktype');
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
  htmlcode('publishwriteup', $wu, $NODE);
}

sub bookmark
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $node_id = $query->param('bookmark_id');

  $node_id or return;
  return if $APP->isGuest($USER);
  return unless htmlcode('verifyRequest', 'bookmark');
  my $LINKTYPE = getNode('bookmark', 'linktype');

  $DB->sqlInsert('links', {from_node => getId($USER), to_node => $node_id, linktype => getId($LINKTYPE)});

  return 1 if $$VARS{no_bookmarkinformer};

  my $tempnode = getNodeById($node_id);
  return 1 if (($$tempnode{type}{title} ne "writeup") && ($$tempnode{type}{title} ne "e2node")); #only send CME for writeups & e2nodes

  my $eddie = getId(getNode('Cool Man Eddie','user'));
  my @tempgroup = @{ $$tempnode{group} } if $$tempnode{group};
  my @group;
  my $TV;
  foreach (@tempgroup)
  {
    my $not_self_user = ($_ != getId($USER));
    $TV = getVars(getNodeById($_)->{author_user});
    if ((!$$TV{no_bookmarknotification})&&($not_self_user))
    {
      push @group, $_;
    }
  }

  my $nt = $$tempnode{title};
  my ($eddiemessage, $nodeshell) = ('', 0);
  my @writeupAuthors;

  if(scalar(@tempgroup))
  {
    return 1 unless @group;
    @writeupAuthors = map { getNodeById($_)->{author_user} } @group;
    $eddiemessage = "the entire node [$nt], in which you have a writeup,";
  } else {
    my $notifiee = $$tempnode{createdby_user} || $$tempnode{author_user};
    $TV = getVars(getNodeById($notifiee));
    if ($$TV{no_bookmarknotification})
    {
      return 1;
    }
    if (getId($USER) == $notifiee)
    {
      return 1;
    }

    push @writeupAuthors, $notifiee;
    if ($$tempnode{type}{title} eq 'writeup')
    {
      $eddiemessage ="your writeup [$nt]";
    } else {
      $nodeshell = 1;
      $eddiemessage ="your nodeshell [$nt]";
    }
  }

  my $notification = getNode("bookmark","notification")->{node_id};
  foreach (@writeupAuthors)
  {
    my $authorVars = getVars(getNodeById($_));
    if ($$authorVars{settings})
    {
      if ( from_json($$authorVars{settings})->{notifications}->{$notification})
      {
        htmlcode('addNotification', $notification, $_, {
          writeup_id => $$tempnode{node_id}
          , bookmark_user => $$USER{user_id}
          , nodeshell => $nodeshell});
      }
    }
  }

  htmlcode('sendPrivateMessage',{
    fromgroup_id => $$USER{node_id},
    'author_id' => $eddie,
    'recipient_id' => \@writeupAuthors,
    'message' => 'Yo, '.$eddiemessage.' was bookmarked. Dig it, baby2.',});

1;

}

sub vote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $$USER{votesleft};
  return if isSuspended($USER, "vote");
  return if $APP->isGuest($USER);
  my @params = $query->param;
  my $defID = getId(getNode('definition','writeuptype')) || 0;

  my $UID = getId($USER) || 0;

  my $oldXP = $$USER{experience};
  my $prev_uid = 0;
  my $numTimes=0;
  my $VSETTINGS = getVars(getNode('vote settings', 'setting'));
  my $countPlus=0;
  my $countMinus=0;

  foreach (@params)
  {
    next unless /^vote\_\_(\d+)$/;
    my $N = $1;
    my $val = $query->param($_);
    next unless ($val eq '1' or $val eq '-1');

    getRef($N);

    next unless $N;
    next unless $$N{type}{title} eq 'writeup' ;
    next if $$N{author_user} == $UID;
    next if $$N{wrtype_writeuptype}==$defID;

    if ( $APP->isUnvotable($N) )
    {
      htmlcode('logWarning',getId($N).',vote: attempt on disallowed node: '.$val.' from '.$UID);
      next;
    }

    if ($$N{author_user}==$prev_uid)
    {
      ++$numTimes;
      if ($val>0)
      {
        ++$countPlus;
      } elsif ($val<0) {
        ++$countMinus;
      }
    } else {
      $prev_uid = $$N{author_user};
    }

    castVote(getId($N), $USER, $val, 0, $VSETTINGS);


    htmlcode('achievementsByType','vote,'.$$USER{user_id});
    htmlcode('achievementsByType','reputation,'.$$N{author_user});


    last unless $$USER{votesleft};
  }

  if ($numTimes)
  {
    ++$numTimes;
    htmlcode('logWarning',',vote: multiple ('.$numTimes.') votes ('.$countPlus.'+  '.$countMinus.'-) for same person: '.$prev_uid);
  }

}

1;
