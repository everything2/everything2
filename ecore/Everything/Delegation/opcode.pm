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
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *hasVoted = *Everything::HTML::hasVoted;
  *getHRLF = *Everything::HTML::getHRLF;
  *evalCode = *Everything::HTML::evalCode;
  *getCompiledCode = *Everything::HTML::getCompiledCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *castVote = *Everything::HTML::castVote;
  *adjustGP = *Everything::HTML::adjustGP;
  *adjustExp = *Everything::HTML::adjustExp;
} 

# Used by bookmark, cool, weblog
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
  my @tempgroup = (); @tempgroup = @{ $$tempnode{group} } if $$tempnode{group};
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

sub bless
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isGod($USER);
  my $U = $query->param('bless_id');
  $U = getNode($query->param("node"), 'user') if ($query->param('node'));
  getRef $U;

  return unless $$U{type}{title} eq 'user';

  my $gp = int($query->param('experience')); # I have no idea where this parameter might get called from, so I'm leaving it in place to be on the safe side.
  $gp ||= 10;

  $$U{gp} += $gp;
  $$U{karma} += 1;

  htmlcode('achievementsByType','karma');

  $APP->securityLog(getNode("bless","opcode"), $USER, "$$U{title} was blessed 10GP by $$USER{title}");

  htmlcode('sendPrivateMessage',{
    'author_id' => getId(getNode('Cool Man Eddie', 'user')),
    'recipient_id' => $$U{user_id},
    'message' => "Whoa, you&rsquo;ve just been [bless|blessed]!"});

  updateNode($U, -1);
  adjustGP($U, $gp);

}

sub curse
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Currently disabled
  return;
  return unless isGod($USER);
  my $U = $query->param('node_id');
  getRef $U;

  $$U{experience} -= 10;
  $$U{karma} -= 1;

  updateNode($U, -1);
}

sub bestow
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isGod($USER);
  my $U = $query->param('bestow_id');
  getRef $U;

  $$U{votesleft} += 25;
  $$U{karma} += 1;

  $APP->securityLog(getNode("bestow","opcode"), $USER, "$$U{title} was given 25 votes by $$USER{title}");

  updateNode($U, -1);
}

sub message
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);

  my $for_user = $query->param('sendto');
  my $message = $query->param('message');
  my $UID = undef; $UID = getId($USER)||0;
  my $isRoot = $APP->isAdmin($USER);
  my $isChanop = $APP->isChanop($USER, "nogods");

  foreach($query->param)
  {
    if($_ =~ /^deletemsg\_(\d+)$/)
    {
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot || ($UID==$$MSG{for_user});
      $DB->sqlDelete('message', "message_id=$$MSG{message_id}");
    } elsif($_ =~ /^archive\_(\d+)$/) {
      #NPB FIXME Perl Monks is better
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($UID==$$MSG{for_user});
      my $realTime = $$MSG{tstamp};
      $DB->sqlUpdate('message', {archive=>1, tstamp=>$realTime}, 'message_id='.$$MSG{message_id});
    } elsif($_ =~ /^unarchive\_(\d+)$/) {
      my $MSG = $DB->sqlSelectHashref('*', 'message', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($UID==$$MSG{for_user});
      my $realTime = $$MSG{tstamp};
      $DB->sqlUpdate('message', {archive=>0, tstamp=>$realTime}, 'message_id='.$$MSG{message_id});
    }
  }

  return if $$VARS{borged} or ($$USER{title} eq 'everyone');

  my $sushash = $DB->sqlSelectHashref("suspension_sustype", "suspension","suspension_user=$$USER{node_id} and suspension_sustype='1948205'"); # Check for unverified email
  return if ($$sushash{suspension_sustype}&& $for_user==0);

  $message =~ s/^\s+|\s+$//g;
  return if $message eq '';

  #Replace synonyms for /whisper just with /whisper.
  $message =~ s/^\/(small|aside|ooc|whispers?|monologue)\b/\/whisper/i; 

  #Frivolous synonyms for singing
  $message =~ s/^\/(aria|chant|song|rap|gregorianchant)\b/\/sing/i;

  #Frivolous synonyms for death
  $message =~ s/^\/(tomb|sepulchral|doom|reaper)\b/\/death/i;

  #Synonym for /me's
  $message =~ s/^\/my/\/me\'s/i;

  #Synonym for /roll 1d2
  if ($message =~ /^\/(flip|coinflip)\s*$/i) { $message = "/rolls 1d2"; }

  # The validCommand check is used to prevent accidental dropped messages and similar
  #  mistakes.  Commands which are passed through to be posted in the room (and hence
  #  are parsed by [showchatter]) need to be in this list.
  my $validCommand = 0;
  my @validCommands = qw/small aside whisper whispers death monologue sing sings me me's roll rolls
    fireball sanctify/;

  my %validCommands = map { $_ => 1 } @validCommands;
  if ($message =~ m!^/([^\s]+)!)
  {
    my $command = $1;
    $validCommand = 1 if $validCommands{$command};
  }

  if($message =~ /^\/(invite)\s+(\S*)$/si)
  {
    if($$USER{in_room})
    {
      my $R = getNodeById($$USER{in_room});
      my $room;
      $room = $$R{title} if $R;
      $message = "/msg $2 come join me in [$$R{title}]";
    } else {
      $message = "/msg $2 come join me outside";
    }
  }

  my $valid = getVars(getNode('egg commands','setting'));

  if ($message =~ /^\/(\S*)?\s+(.+?)\s*$/)
  {
    my $phrase = $1;
    $phrase = substr($phrase,0,-1) if (!$$valid{$phrase});
    if ($$valid{$phrase})
    {
      $validCommand = 1;
      if ($$VARS{easter_eggs} < 1)
      {
        my $message = "You have no eggs to do that with.";
        $query->param('sentmessage', $message);
        return;
      }

      my $uName = $2;
      my $recUser = getNode($uName,"user");
      if (!$recUser)
      {
        $uName =~ s/\_/ /gs;
        $recUser = getNode($uName, 'user');
      }

      return unless $recUser;
      if ($$recUser{user_id} == $$USER{user_id})
      {
        my $message = "You can't do that to yourself!";
        $query->param('sentmessage', $message);
        return;
      }
		
      $$VARS{easter_eggs}--;
      adjustGP($recUser, 3);
      $message = "/".$phrase." $uName";
    }
  }

  ### Fireball level power --mauler

  if ($message =~ /^\/fireball\s+(.*)$/i)
  {
    my $minLvl = 15;

    if (($APP->getLevel($USER) >= $minLvl) || ($isRoot))
    {
      if ($$VARS{easter_eggs} > 0)
      {
        my $fireballer = $$USER{title};
        my $uName = $1;
        my $recUser = getNode($uName,"user");
        my $fireballee = $uName;
        if (!$recUser)
        {
          $uName =~ s/\_/ /gs;
          $recUser = getNode($uName, 'user');
        }

        if ($recUser)
        {
          $fireballee = $$recUser{title};
        }

        $$VARS{easter_eggs}--;
        $$recUser{sanctity} += 1;
        updateNode($recUser, -1);
        adjustGP($recUser, 5);

        htmlcode('sendPrivateMessage',{
          'recipient_id' => getId($recUser),
          'message' => "WHOOSH! You feel yourself engulfed in flames! "
          . "It burns! It burns! Or does it? After a moment, you feel "
          . "a pleasant sensation. Like a warm embrace. And you "
          . "realize that this is not fire after all, but [5 GP|love]."
          . " The kind of love that could only have come from user "
          . "[$fireballer].",
          'author' => 'fireball',
        });

        my $rnd = int(rand(10));

        if ($rnd == 1)
        {
          $message = "/conflagrate $fireballee";
        } elsif ($rnd == 2) {
          $message = "/immolate $fireballee";
        } elsif ($rnd == 3) {
          $message = "/singe $fireballee";
        } elsif ($rnd == 4) {
          $message = "/explode $fireballee";
        } elsif ($rnd == 5) {
          $message = "/limn $fireballee";
        } else {
          $message = "/fireball $fireballee";
        }
      } else {
        $message = "/me\'s fireball fizzles.";
      }
    } else {

      $message = "/me\'s fireball fizzles.";
    }
  }
  ## End fireball

  ## Sanctify as a catbox command --mauler

  if (($message =~ /^\/sanctify\s+(.*)$/i))
  {
    return if ($$VARS{GPoptout});
    my $minLvl = 11;
    my $Sanctificity = 10;
    if (($APP->getLevel($USER) >= $minLvl) || ($isRoot))
    {
      my $sanctifyer = $$USER{title};
      my $uName = $1;
      my $recUser = getNode($uName,"user");
      my $sanctee = $uName;
      if (!$recUser)
      {
        $uName =~ s/\_/ /gs;
        $recUser = getNode($uName, 'user');
      }

      if ($recUser) 
      {	
        $sanctee = $$recUser{title};
      }

      return unless $recUser;
      return if ($$recUser{user_id} == $$USER{user_id});

      $$recUser{sanctity} += 1;
      updateNode($recUser, -1);

      adjustGP($recUser, $Sanctificity);
      adjustGP($USER, -$Sanctificity);
      $APP->securityLog(getNode('Sanctify user', 'superdoc'), $USER, "$$USER{title} sanctified $sanctee with $Sanctificity GP.");

      htmlcode('sendPrivateMessage',{
        'recipient_id' => getId($recUser),
        'message' => "Whoa! You've been [sanctify|sanctified] in the catbox by [$sanctifyer]!",
        'author' => 'Cool Man Eddie'});

      $message = "/sanctify $sanctee";
    } else {
      # $message = "/me has insufficient sanctity.";
      return;
    }
  }

  ## End Sanctify command

  ## dice rolling command code
  if ($message =~ /^\/roll\s?(.*)$/i)
  {
    my @dice = ();
    my $totalizer = 0;
    my $rollstr = $1;
    $rollstr =~ s/\s//g; ## remove spaces
    ## eg: 3d6[+1]
    ## anything extra is trimmed and ignored
    if ($rollstr =~ m/((\d+)d(-?\d+)(([\+-])(\d+))?(keep(\d+))?)/i)
    {
      my $diceCount = int($2);
      my $diceSides = int($3);
      my $diceKept = int($8);

      # If no "keep" text or negative dice kept, keep all dice
      if ($diceKept <= 0 || $diceKept > $diceCount)
      {
        $diceKept = $diceCount;
      }

      if ($diceCount > 1000) ## prevent silliness
      {
        $message = "/rolls too many dice and makes a mess.";
      }elsif ($diceSides < 0) {
        ## prevent silliness
        $message = "/rolls anti-dice, keep them away from the normal dice please.";
      } else {
        unless ($diceSides == 0) ## zero-sided dice
        {
          for (my $i=0; $i < $diceCount; $i++) 
          {
            push @dice, int(rand($diceSides))+1;
          }

          @dice = reverse sort @dice;
          for (my $i=0; $i < $diceKept; $i++)
          {
            $totalizer += $dice[$i];
          }
        }

        if ($5 eq '+')
        {
          $totalizer += $6;
        }

        if ($5 eq '-')
        {
          $totalizer -= $6;
        }
	
        $message = "/rolls " . $1 . " &rarr; " . $totalizer;
      }
    } else { 

      $message = "/rolls poorly, format: 3d6&#91;+1&#93;";
    }
  }
  ## end dice rolling command code

  my $helpTopics = $message;
  my ($sendHelp, $recipient) = (undef, undef);
  while ($helpTopics =~ /^\/help\s+(.*)$/i)
  {
    $sendHelp = 1;
    my $helpVars = getVars(getNode('help topics','setting'));
    $recipient = $$USER{user_id} unless $recipient;
    my $helpText = $1;
    $helpTopics = $helpVars->{$helpText};
    if (!$helpTopics)
    {
      my $theTopic = encodeHTML($1);
      $helpTopics = "Sorry, no information on $theTopic is available. Please try [Everything2 Help] for further assistance.";

      if (($helpText =~ /^(\S*)?\s+(\S*)/)&&($isRoot))
      {
        $helpTopics = $helpVars->{$2};
        return unless $helpTopics;
        $recipient = getNode($1, 'user')->{user_id};
      }
    }
  }

  if ($sendHelp)
  {
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode('Virgil', 'user')),
      'recipient_id' => $recipient,
      'message' => $helpTopics, });

    return $helpTopics;
  }

  if($message =~ /^\/(msg\??|tell\??)(\{.+?\}\??|\s+\S+)(\s+.+)?$/si)
  {
    # values:
    # $1 - msg/tell and possibly online only
    # $2 - recipient(s) and possibly online only
    # $3 - message
    my $isONO = (substr($1,-1,1) eq '?');
    my $allTargets = $2;
    my $message = $3;

    return if $message=~/^\s+$/;

    my @recipients = ();
    if(substr($allTargets,0,1) eq '{')
    {
      # given multiple recipients
      $isONO ||= (substr($allTargets,-1,1) eq '?');
      if($allTargets =~ /^\{(.+?)\}\??$/)
      {
        # should always match
        @recipients = split(/\s+/, $1);  #break apart names by spaces
      }
    } else {
      # only a single recipient
      if($allTargets =~ /(\S+)/)
      {
        # should always match
        @recipients = ($1);
      }
    }

    unless(scalar(@recipients))
    {
      # invalid message command, so give error
      $message = 'The format of your private message was unrecognized. You tried to send "'.$message.'".';
      @recipients = ($USER->{title});
    }

    htmlcode('sendPrivateMessage',{
      'recipient' => \@recipients,
      'message' => $message,
      'ono' => $isONO,});

  } elsif($message =~ /^\/old(msg\??|tell\??)\s+(\S+)\s+(.+)$/si) {
    # for msg typo-N-Wing changed \S* and .* into \S+ and .+
    my $onlyOnline = (substr($1,-1,1) eq '?') ? 1 : 0;
    $message = $3;
    my $user = $2;
    my $FORWARDS = getVars(getNode('chatterbox forward','setting'));
    #$user = $$FORWARDS{$user} if exists $$FORWARDS{$user};
    $user = $$FORWARDS{lc($user)} if exists $$FORWARDS{lc($user)};

    my $U = getNode($user, 'usergroup');
    $U = getNode($user, 'user') unless $U;
    $user =~ s/\_/ /gs unless $U;
    $U = getNode($user, 'usergroup') unless $U;
    $U = getNode($user, 'user') unless $U;
    $U = getNode($user, 'lockeduser') unless $U;

    if(not $U)
    {
      $DB->sqlInsert('message', {msgtext => "You tried to talk to $user, but they don't exist on this system:\"$message\"", author_user => getId(getNode('root','user')), for_user =>getId($USER) });
      return;
    }

    my $ugID = 0;
    if($$U{type}{title} eq 'usergroup')
    {
      $ugID = getId($U) || 0;
      unless(Everything::isApproved($USER, $U))
      {
        $DB->sqlInsert('message', {msgtext => "You aren't a part of the user group \"$$U{title}\", so you can't say \"$message\".", author_user => getId(getNode('root','user')), for_user=>getId($USER) });
        return;
      }

    }

    my @rec = ();

    my $m = undef;
    if(exists $$U{group})
    {
      my $csr = $DB->sqlSelectMany('messageignore_id', 'messageignore', 'ignore_node='.$$U{node_id});
      my %ignores = ();
      while (my ($ig) = $csr->fetchrow)
      {
        $ignores{$ig} = 1;
      }
      $csr->finish;
      @rec = map { exists($ignores{getId($_)}) ? () : $_} @{$DB->selectNodegroupFlat($U)};
      # $message = '['.uc($$U{title}).']: ' . $message;
      for(my $i=0;$i<scalar(@rec);++$i)
      {
        $m=$rec[$i];
        $m=$$m{node_id};
        $rec[$i] = $m;
      }

      push(@rec, $UID); #so when admins msg a group they aren't in, they'll get the msg they sent

      # sorted for easy user duplication detection
      @rec = sort { $a <=> $b } @rec;
    } else {
      push @rec, getId($U) unless $DB->sqlSelect('ignore_node', 'messageignore', "messageignore_id=$$U{node_id} and ignore_node=$$USER{node_id}");
    }

    if($onlyOnline)
    {
      $message = 'ONO: ' . $message;
      my %onlines = ();
      my $csr = $DB->sqlSelectMany('member_user', 'room', '', '');
      while( my ($ig) = $csr->fetchrow)
      {
        $onlines{$ig} = 1;
      }
      $csr->finish;
      my @actives = ();
      foreach $m (@rec)
      {
        if($onlines{$m})
        {
          push @actives, $m;
        } else {
          my $v = getVars(getNodeById($m));
          if($$v{'getofflinemsgs'})
          {
            push @actives, $m;
          }
        }
      }

      @rec = @actives;
    }

    # group archive - have to do this after online only check
    if($ugID and $APP->getParameter($ugID, 'allow_message_archive') )
    {
      push @rec, $$U{node_id};
    }

    # add message to table for each user
    my $old = 0;
    foreach $m (@rec)
    {
      next if $m==$old;
      $DB->sqlInsert('message', {msgtext=>$message, author_user=>$UID, for_user=>$m, for_usergroup=>$ugID });
      $old = $m;
    }

    $query->param('sentmessage', 'you said "' . encodeHTML($message) . '" to '.linkNode($U));

    # botched /msg test
  } elsif( ($message =~ /^\W?(.sg|m^[aeiouy]g|ms.|smg|mgs)/i) && !$$VARS{noTypoCheck} ) {

    $DB->sqlInsert('message',{
      msgtext=>'typo alert: '.$message,
      author_user=>$UID,
      for_user=>$UID });

  } elsif( ($isRoot || $isChanop) and $message =~ /^\/fakeborg\s+(.*)$/i) {
    my $fakeTarget = $1;
    return unless length($fakeTarget);

    my $message = '/me has swallowed ['.$fakeTarget.']. ';

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

    $DB->sqlInsert('message', {msgtext => $sendMessage, author_user => getId($BORG), for_user => $UID });

    # update user stats
    my $V = getVars($U);

    ++$$V{numborged};
    $$V{borged} = time;
    setVars($U, $V);
    $DB->sqlUpdate('room', {borgd => '1'}, 'member_user='.getId($U));

    # update nodelet
    my $OTHERUSERS = getNode('other users', 'nodelet');
    $$OTHERUSERS{nltext} =  Everything::HTML::parseCode($$OTHERUSERS{nlcode}, $OTHERUSERS);
    updateNode($OTHERUSERS, -1);

    htmlcode('addNotification', 'chanop borged user', 0, {
      chanop_id => $USER->{node_id},
      user_id => $U->{node_id} });

    # as of 2008-08-12, not showing messages in public area
    return;

    # display message in chatterbox
    my $message = "/me has swallowed [$user]. ";

    my @EDBURSTS = (
      '*BURP*', 'Mmmm...', "[$user] is good food!",
      "[$user] was tasty!", 'keep \'em coming!',
      "[$user] yummy! More!", '[EDB] needed that!',
      '*GULP*','moist noder flesh', '*B R A P *' );

    $message .= $EDBURSTS[int(rand(@EDBURSTS))];

    $DB->sqlInsert('message', {
      msgtext => $message,
      author_user => getId($BORG),
      for_user => 0,
      room => $$USER{in_room} });

    return;

  } elsif(($isRoot or $isChanop) and $message=~/^\/topic\s+(.*)$/i) {

    $message = $1;
    utf8::encode($message);

    my $settingsnode = getNodeById(1149799); #More hard-coded goodness for speed.
    my $topics = getVars($settingsnode);

    $$topics{$$USER{in_room}} = $message;

    setVars($settingsnode, $topics);

    # Log topic changes -- the gift shop is the official "topic change location"
    $message = encodeHTML($message);
    my $msgOp = getNode('E2 Gift Shop', 'superdoc');
    my $room = getNodeById($$USER{in_room});
    my $roomName = $$USER{in_room} == 0 ? "outside" : ($room ? $$room{title} : "missing room ($$USER{in_room})");
    $APP->securityLog(getNode('E2 Gift Shop', 'superdoc'), $USER, "\[$$USER{title}\[user\]\] changed $roomName topic to '$message'");

  } elsif( ($isRoot || $isChanop) and $message=~ /^\/sayas\s+(\S*)\s+(.*)$/si) {

    my $message = $2;
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

    $DB->sqlInsert('message', {msgtext => $message, author_user => $rootID, for_user => $UID }) if $message;

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

  } elsif( ($message =~ m!^\s*/!) && !$validCommand && !$$VARS{noTypoCheck} ) {

    $DB->sqlInsert('message',{
      msgtext => "You typed an invalid command: $message",
      author_user => $UID,
      for_user => $UID,});

  } else {
    return if $$VARS{publicchatteroff};

    $message = substr($message, 0, 512); # keep old, shorter length for public chatter
    utf8::encode($message);

    my $messageInterval = 480;
    my $wherestr = "for_user=0 and tstamp >= date_sub(now(), interval $messageInterval second)";
    $wherestr .= ' and room='.$$USER{in_room} unless ($$VARS{omniphonic});
    $wherestr .= ' and author_user='.$$USER{user_id};

    my $lastmessage = $DB->sqlSelect('trim(msgtext)', 'message', $wherestr." order by message_id desc limit 1");
    my $trimmedMessage = $message;
    $trimmedMessage =~ s/^\s+//;
    $trimmedMessage =~ s/\s+$//;
    if ($lastmessage eq $trimmedMessage)
    {
      return;
    }

    return if (isSuspended($USER,"chat"));
    return if ($$VARS{infected} == 1);

    $DB->sqlInsert('message', {msgtext => $message, author_user => getId($USER), for_user => 0, room => $$USER{in_room}});
  }

}

sub message_outbox
{
  # Standard vars for the opcode processing
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Guests aren't allowed to perform message_outbox actions
  return if $APP->isGuest($USER);

  my $UID      = undef; $UID = getId($USER)||0;
  my $isRoot   = undef; $isRoot = $APP->isAdmin($USER);
  my $MSG      = undef; # Populated below with outbox message loaded from the DB by id

  foreach($query->param)
  {
    if($_ =~ /^deletemsg\_(\d+)$/)
    {

      # Delete a message given param named : deletemsg_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot || ($UID==$$MSG{author_user});
      $DB->sqlDelete('message_outbox', "message_id=$$MSG{message_id}");

    } elsif($_ =~ /^archive\_(\d+)$/) {

      # Archive a message given param named : archive_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($UID==$$MSG{author_user});
      $DB->sqlUpdate('message_outbox', {archive=>1, tstamp=>$$MSG{tstamp}}, 'message_id='.$$MSG{message_id});

    } elsif($_ =~ /^unarchive\_(\d+)$/) {

      # Un-archive a message given param named : unarchive_<messageid>
      $MSG = $DB->sqlSelectHashref('*', 'message_outbox', "message_id=$1");
      next unless $MSG;
      next unless $isRoot||($UID==$$MSG{author_user});
      $DB->sqlUpdate('message_outbox', {archive=>0, tstamp=>$$MSG{tstamp}}, 'message_id='.$$MSG{message_id});
    }
  }

}


sub cool
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # single-writeup C!

  my ($cid) = $query->param('cool_id');
  my $uid = getId($USER);

  my $COOL = getNodeById($cid);
  getRef($COOL);

  return unless $COOL;
  return unless $$COOL{type}{title} eq 'writeup';
  return if $$COOL{author_user} == $uid;
  return if isSuspended($USER, "cool");

  my $forceAllow = 0;
  return unless $forceAllow || ($$VARS{cools} > 0);

  return if ($DB->sqlSelect('cooledby_user', 'coolwriteups', 'coolwriteups_id='.$cid.' and cooledby_user = '.$uid.' limit 1') || 0 );

  --$$VARS{cools} unless $forceAllow;
  setVars($USER, $VARS); #Discount chings right away before anything else.

  adjustExp($$COOL{author_user}, 20);
  $DB->sqlInsert('coolwriteups', {coolwriteups_id => $cid, cooledby_user => $uid});
  $$COOL{cooled}++;
  updateNode($COOL, -1);

  my $coolVars = getVars($$COOL{author_user});

  my $cooledNotification = getNode("cooled","notification")->{node_id};
  if ($$coolVars{settings})
  {
    if (from_json($$coolVars{settings})->{notifications}->{$cooledNotification})
    {
      my $argSet = { writeup_id => $cid, cooluser_id => $uid};
      my $argStr = to_json($argSet);
      my $addNotifier = htmlcode('addNotification', $cooledNotification , $$COOL{author_user},$argStr);
    }
  }


  unless ($coolVars->{no_coolnotification})
  {
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode('Cool Man Eddie', 'user')),
      'recipient_id' => $$COOL{author_user},
      'message' => 'Hey, [' . $$USER{title} . '[user]] just cooled [' . getNode($$COOL{parent_e2node})->{title} . '], baby!',
    });
  }

  htmlcode('achievementsByType','cool,'.$uid);
  htmlcode('achievementsByType','cool,'.$$COOL{author_user});

  return '';
}

sub weblog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $SRC = $query->param("source");

  my $N = $query->param('target');
  $N ||= $query->param("node_id");

  getRef ($N);
  getRef $SRC;

  return unless $N;
  return unless $SRC;
  return unless $$N{type}{sqltablelist} =~ /document/;
  return if $$N{nodetype} eq 'usergroup'; 

  if ($$SRC{type}{title} eq 'usergroup')
  {
    return unless Everything::isApproved($USER, $SRC);
  } elsif ($$SRC{title} eq 'News for noders. Stuff that matters.') {
    return unless Everything::isApproved($USER, getNode('everything editors','usergroup'));
  } else {
    return unless isGod($USER);
  }

  my $exists = $DB->sqlSelect("weblog_id","weblog","weblog_id=".getId($SRC)." and to_node=".getId($N));

  if ($exists)
  {
    $DB->sqlUpdate("weblog",{removedby_user => 0, linkedby_user => getId($USER)},"weblog_id=".getId($SRC)." and to_node=".getId($N));
  } else {
    $DB->sqlInsert("weblog", {
      weblog_id => getId($SRC), 
      to_node => getId($N),
      linkedby_user => getId($USER),
      -linkedtime => 'now()'});

    my $weblogNotification = getNode("weblog","notification")->{node_id};
    foreach my $notifiee (@{$$SRC{group}})
    {
      my $v = getVars(getNodeById($notifiee));
      if ($$v{settings})
      {
        if (from_json($$v{settings})->{notifications}->{$weblogNotification})
        {
          htmlcode('addNotification', $weblogNotification, $notifiee, {
            writeup_id => getId($N),
            group_id => $$SRC{node_id} });
        }
      }
    }
  }

  if ($$SRC{title} eq 'News for noders. Stuff that matters.')
  {
    htmlcode('addNotification', 'frontpage', 0, { frontpage_item_id => getId($N) });
  }

}

sub removeweblog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This removes one item from a weblog
  my $src = int($query->param("source"));
  my $to_node = int($query->param("to_node"));

  # usergroup owner
  my $isOwner = 0;
  $isOwner = 1 if $$USER{node_id} == $APP -> getParameter($src, 'usergroup_owner');
  my $canRemove = isGod($USER) || $isOwner || $DB -> sqlSelect( "weblog_id" , "weblog" ,
    "weblog_id=$src and to_node=$to_node and linkedby_user=$$USER{ user_id }" );

  return unless $canRemove;
  return unless $src && $to_node ;
  $DB->getDatabaseHandle()->do("update weblog set removedby_user=$$USER{ user_id } where weblog_id=$src && to_node=$to_node");

}

# There are still references to this in the javascript that need to get cleaned out
#
sub massacre
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my @params = $query->param;
  my @deathrow = ();
  my $nr = getId(getNode('node row', 'superdoc'));
  foreach(@params)
  {
    next unless /^killnode(\d+)$/;
    next if $DB->sqlSelect('linkedby_user', 'weblog', "weblog_id=$nr and to_node=$1"); #hopefully, this will prevent double-kills

    push @deathrow, $1;
  }

  return unless @deathrow;

  my $UID = $$USER{node_id}||0; # ID of person that is deleting
  return if !$UID;
  my $aid = undef; #ID of user whose WU is killed
  my $V = undef; #vars of that user
  my $nid = undef;
  my $m = undef;
  my $r = undef; #reason
  my $nt = undef; #node title
  my $z = undef;

  foreach $nid (@deathrow)
  {
    my $N = getNodeById($nid);
    next unless($N);
    # security fix to make sure that we can't delete non-writeups.
    next unless($$N{type_nodetype} == getId(getType('writeup')));
    $aid = $$N{author_user};
    my $parentID = $$N{parent_e2node};
    my $amount = -5;
    my $noexp = 0;
    $noexp = 1 if $APP->isMaintenanceNode($N);

    unless($noexp)
    {
      adjustExp($aid, $amount);
    }

    if(!$query->param('instakill'.$nid))
    {
      $DB->sqlInsert('weblog',{ 
        weblog_id => $nr,
        to_node => $nid,
        linkedby_user => getId($USER),
        -linkedtime => 'now()'});
    } else {
        nukeNode($N, -1);
    }
	
    if($query->param('hidewu'.$nid))
    {
      $DB -> sqlUpdate('newwriteup', { notnew=>'1' }, "node_id=$nid");
      $DB -> sqlUpdate('writeup', { notnew=>'1' }, "writeup_id=$nid");
      $$N{notnew} = '1' ; # update cached version
    }

    next unless $aid; #skip /msg if no WU author
    next if ($aid==$UID) && $query->param('noklapmsg'.$nid); #no /msg to self

    $V = getVars($aid);
    $z = $$V{'no_notify_kill'} ? 0 : 1;

    $nt = $$N{title};
    if($nt=~/^(.*) \(.+?\)$/)
    {
      $nt=$1;
    }

    if($z && $noexp)
    {
      # don't send msg for maintenance stuff, unless there is a reason
      $z=0 unless (defined $query->param('killreason'.$nid)) && (length($query->param('killreason'.$nid))!=0);
    }

    next unless $z; # not msg-worthy

    $m = (
      ( (defined $query->param('killreason'.$nid)) && (length($r=$query->param('killreason'.$nid))!=0) )
      ? $r.' '
      : '');

    my $msgHash = {
      msgtext=>'I deleted your writeup ['.$nt.']. '.$m.'[Node Heaven] will become its new residence.',
      author_user=>$UID,
      for_user=>$aid};

    $DB->sqlInsert('message', $msgHash);

    my $aut = getNodeById($aid);
    $APP->securityLog(getNode('massacre', 'opcode'), $UID, "[$nt] by [$$aut{title}] was killed: $m");
  }	

  htmlcode('update New Writeups data');
}

sub lockroom
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
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
}

sub resurrect
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isGod($USER);

  my $node_id=$query->param('olde2nodeid');
  return unless $node_id;

  my $N = htmlcode("resurrectNode", $node_id);
  return unless $N;
  my $id = htmlcode("reinsertCorpse",$N);

  $query->param('node_id', $id);
}

sub bucketop
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isGod($USER);
  if($query->param("bgroupadd"))
  {
    my $group = getNode($query->param("node_id"));

    return unless($group && $$group{type}{grouptable});

    foreach my $param ($query->param)
    {
      next unless($param =~ /^bnode_(\d+)$/);

      # For some reason, passing $1 here causes the function to receive undef.
      # Probably has something to do with default vars.  So, we need to assign
      # what we found to a scoped var.
      my $insert = $1;
      insertIntoNodegroup($group, $USER, $insert);
    }
  }

  if($query->param("bdrop") or $query->param("dropexec"))
  {
    my $bucket = $$VARS{nodebucket};
    foreach my $param ($query->param)
    {
      next unless($param =~ /^bnode_(\d+)$/);

      # Remove the numeric id from the bucket list
      $bucket =~ s/$1,?//;
      $bucket =~ s/,$//;
    }

    $$VARS{nodebucket} = $bucket;
    delete $$VARS{nodebucket} unless($bucket && $bucket ne "");
  }
}

sub addbucket
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  foreach my $bnode ($query->param())
  {
    next unless($bnode =~ /^bnode_([0-9]*)$/);
    next if ($$VARS{nodebucket} =~ /$1/);

    $$VARS{nodebucket} .= "," if($$VARS{nodebucket} && $$VARS{nodebucket} ne "");

    $$VARS{nodebucket} .= $1;
  }

}

sub linktrim
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless htmlcode('verifyRequest', 'linktrim');

  my $from_node = int $query->param('cutlinkfrom');
  my $trimlinktype = int $query->param('linktype');
  my $linktype = getNodeById($trimlinktype);

  return unless $from_node;

  my $linkName = undef; $linkName = $$linktype{title} if $linktype && $$linktype{type}{title} eq 'linktype';

  if ($linkName eq '')
  {
    $linkName = 'softlink';
    $trimlinktype = 0;
  }

  my %trimmable = (
    'softlink' => 1,
    'firmlink' => 1,
    'favorite' => 1,
  );

  return unless $trimmable{$linkName};

  if ($linkName eq 'softlink' || $linkName eq 'firmlink')
  {
    my $recurseGroups = 1;
    return unless $APP->isEditor($USER);
  } elsif ($linkName eq 'favorite') {
    return unless $from_node == $$USER{node_id};
  }

  foreach ($query->param) {
    next unless /^cutlinkto_(\d+)$/;
    $DB->sqlDelete('links', "from_node=$from_node and to_node=$1 and linktype=".$trimlinktype);
    $DB->sqlDelete('firmlink_note', "from_node=$from_node and to_node=$1") if $$linktype{title} eq 'firmlink';
  }

  1;
}

sub firmlink
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  return unless($query->param('firmlink_to_node'));
  return unless htmlcode('verifyRequestHash', 'firmlink');

  my ($firmtarget, $firmtargetname) = (undef, undef);
  $firmtargetname = $query->param('firmlink_to_node');

  foreach(qw/superdoc document superdocnolinks e2node user/)
  {
    $firmtarget = getNode($firmtargetname, $_);
    last if $firmtarget;
  }
  my $firmfrom = getNodeById($query->param('firmlink_from_id'));
  my $firmtypelink = getNode("firmlink","linktype");
  my $firmtype = undef; $firmtype = $$firmtypelink{node_id} if $firmtypelink;
  my $firmlink_note_text = $query->param('firmlink_note_text');

  return unless $firmtarget && $firmfrom && $firmtype;
  return if($$firmtarget{node_id} == $$firmfrom{node_id});

  $DB->sqlInsert("links", 
  {
    "linktype" => $firmtype, 
    "to_node" => $$firmtarget{node_id},
    "from_node" => $$firmfrom{node_id}
  });

  $DB->sqlInsert("firmlink_note",
  {
    "to_node" => $$firmtarget{node_id},
    "from_node" => $$firmfrom{node_id},
    "firmlink_note_text" => $firmlink_note_text
  }) if $firmlink_note_text ne "";

  return 1;

}

sub insure
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  return unless($query->param('ins_id'));
  my $insnode = getNodeById($query->param('ins_id'));
  return unless $insnode and $$insnode{type}{title} eq 'writeup';

  my $insure = getNode("insure","opcode");
  my $AUTHOR = getNode($$insnode{author_user});
  my $insured = getId(getNode('insured', 'publication_status'));


  if ($$insnode{publication_status} == $insured)
  {
    $$insnode{publication_status} = 0;
    htmlcode('addNodenote', $insnode, "Uninsured by [$$USER{title}\[user]]");
    $DB->sqlDelete("publish", "publish_id = $$insnode{node_id}");
    $APP->securityLog(getNode("insure","opcode"), $USER, "$$USER{title} uninsured \"$$insnode{title}\" by $$AUTHOR{title}");
  } else {
    $$insnode{publication_status} = $insured;
    htmlcode('addNodenote', $insnode, "Insured by [$$USER{title}\[user]]");
    $DB->sqlInsert("publish",{publish_id => $$insnode{node_id}, publisher => $$USER{user_id}});
    $APP->securityLog(getNode("insure","opcode"), $USER, "$$USER{title} insured \"$$insnode{title}\" by $$AUTHOR{title}");
  }

  $DB->updateNode($insnode, -1);
}

sub nodenote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $notetext = $query->param('notetext'); 
  my $notefor = int($query->param('notefor'));

  my $NOTEFOR = getNodeById($notefor);
  return unless $NOTEFOR;

  # Strip dynamic URLs
  $notetext =~ s/\<.*?img.*?src[\s\"\']*?\=[\s\"\']*?.*?\?.*?\>//g;

  foreach($query->param)
  {
    if($_ =~ /^deletenote\_(\d+)$/)
    {
      $DB->sqlDelete('nodenote', "nodenote_id=$1");
      $APP->securityLog(getNode("Recent Node Notes","oppressor_superdoc"), $USER, "removed note on [$$NOTEFOR{title}]");
    }
  }

  htmlcode('addNodenote', $notefor, $notetext, $USER) if $notetext;
}

sub lockaccount
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless(isGod($USER));

  my $uid = $query->param('lock_id');
  return unless $uid;
  htmlcode('lock user account', $uid);
}

sub unlockaccount
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless(isGod($USER));

  my $uid = $query->param('lock_id');
  return unless $uid;
  $uid = getNodeById($uid);

  return unless($$uid{type_nodetype} == getId(getType('user')));
  $$uid{acctlock} = 0;
  updateNode($uid, -1);

  $APP->securityLog(getNode("unlockaccount","opcode"), $USER, "$$uid{title}'s account was unlocked by $$USER{title}");

}

sub hidewriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  if($query->param('hidewriteup'))
  {
    my $writeup = int($query->param('hidewriteup'));
    $DB -> sqlUpdate('newwriteup', { notnew=>'1' }, "node_id=$writeup");
    getRef $writeup;
    $$writeup{notnew} = 1;
    $DB -> updateNode($writeup, -1);
    htmlcode('addNodenote', $writeup, "Hidden by $$USER{title}");
  }
  return "";
}

sub unhidewriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  if($query->param('hidewriteup'))
  {
    my $writeup = int($query->param('hidewriteup'));
    $DB->sqlUpdate('newwriteup', { notnew=>'0' }, "node_id=$writeup");
    getRef $writeup;
    $$writeup{notnew} = 0;
    $DB->updateNode($writeup, -1);
    htmlcode('addNodenote', $writeup, "Unhidden by $$USER{title}");
  }

  return "";
}

1;
