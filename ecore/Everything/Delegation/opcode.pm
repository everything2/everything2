package Everything::Delegation::opcode;

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
  my $PAGELOAD = shift;
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
    'message' => 'Yo, '.$eddiemessage.' was bookmarked. Dig it, baby.',});

  return 1;

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
  return if $APP->isSuspended($USER, "vote");
  return if $APP->isGuest($USER);
  my @params = $query->param;
  my $defID = getId(getNode('definition','writeuptype')) || 0;

  my $userid = getId($USER) || 0;

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
    next if $$N{author_user} == $userid;
    next if $$N{wrtype_writeuptype}==$defID;

    if ( $APP->isUnvotable($N) )
    {
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

    $APP->castVote(getId($N), $USER, $val, 0, $VSETTINGS);


    htmlcode('achievementsByType','vote,'.$$USER{user_id});
    htmlcode('achievementsByType','reputation,'.$$N{author_user});


    last unless $$USER{votesleft};
  }

  if ($numTimes)
  {
    ++$numTimes;
  }

  return; 
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
  $APP->adjustGP($U, $gp);
  return;
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
  # return unless isGod($USER);
  # my $U = $query->param('node_id');
  # getRef $U;

  # $$U{experience} -= 10;
  # $$U{karma} -= 1;
  # updateNode($U, -1);
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
  return;
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

  return if $$VARS{borged} or ($$USER{title} eq 'everyone');

  my $sushash = $DB->sqlSelectHashref("suspension_sustype", "suspension","suspension_user=$$USER{node_id} and suspension_sustype='1948205'"); # Check for unverified email
  return if ($$sushash{suspension_sustype}&& $for_user==0);

  $message = '' if not defined $message;

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
        $query->param('sentmessage', "You have no eggs to do that with");
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
        $query->param('sentmessage', "You can't do that to yourself!");
        return;
      }
		
      $$VARS{easter_eggs}--;
      $APP->adjustGP($recUser, 3);
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
        $APP->adjustGP($recUser, 5);

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

      $APP->adjustGP($recUser, $Sanctificity);
      $APP->adjustGP($USER, -$Sanctificity);
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
      my $theTopic = $APP->encodeHTML($1);
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
    $message = $3;

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

    my $U = getNode($user, 'usergroup');
    $U = getNode($user, 'user') unless $U;

    if($U->{message_forward_to})
    {
      $U = getNodeById($U->{message_forward_to});
    }

    $user =~ s/\_/ /gs unless $U;
    $U = getNode($user, 'usergroup') unless $U;
    $U = getNode($user, 'user') unless $U;

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

      push(@rec, $userid); #so when admins msg a group they aren't in, they'll get the msg they sent

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
      foreach my $recip (@rec)
      {
        if($onlines{$recip})
        {
          push @actives, $recip;
        } else {
          my $v = getVars(getNodeById($recip));
          if($$v{'getofflinemsgs'})
          {
            push @actives, $recip;
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
    foreach my $recip (@rec)
    {
      next if $recip==$old;
      $DB->sqlInsert('message', {msgtext=>$message, author_user=>$userid, for_user=>$recip, for_usergroup=>$ugID });
      $old = $recip;
    }

    $query->param('sentmessage', 'you said "' . $APP->encodeHTML($message) . '" to '.linkNode($U));

    # botched /msg test
  } elsif( ($message =~ /^\W?(.sg|m^[aeiouy]g|ms.|smg|mgs)/i) && !$$VARS{noTypoCheck} ) {

    $DB->sqlInsert('message',{
      msgtext=>'typo alert: '.$message,
      author_user=>$userid,
      for_user=>$userid });
  } elsif( ($isRoot || $isChanop) and $message =~ /^\/drag\s+(\S+)$/i) {
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
    utf8::encode($message);

    my $settingsnode = getNodeById(1149799); #More hard-coded goodness for speed.
    my $topics = getVars($settingsnode);

    $$topics{$$USER{in_room}} = $message;

    setVars($settingsnode, $topics);

    # Log topic changes -- the gift shop is the official "topic change location"
    $message = $APP->encodeHTML($message);
    my $msgOp = getNode('E2 Gift Shop', 'superdoc');
    my $room = getNodeById($$USER{in_room});
    my $roomName = $$USER{in_room} == 0 ? "outside" : ($room ? $$room{title} : "missing room ($$USER{in_room})");
    $APP->securityLog(getNode('E2 Gift Shop', 'superdoc'), $USER, "\[$$USER{title}\[user\]\] changed $roomName topic to '$message'");

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

  } elsif( ($message =~ m!^\s*/!) && !$validCommand && !$$VARS{noTypoCheck} ) {

    $DB->sqlInsert('message',{
      msgtext => "You typed an invalid command: $message",
      author_user => $userid,
      for_user => $userid,});

  } else {
    # Send public chatter via Application method
    $APP->sendPublicChatter($USER, $message, $VARS);
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
  my $PAGELOAD = shift;
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

  my $cid = $query->param('cool_id');
  my $uid = getId($USER);

  my $COOL = getNodeById($cid);
  getRef($COOL);

  return unless $COOL;
  return unless $$COOL{type}{title} eq 'writeup';
  return if $$COOL{author_user} == $uid;
  return if $APP->isSuspended($USER, "cool");

  my $forceAllow = 0;
  return unless $forceAllow || ($$VARS{cools} > 0);

  return if ($DB->sqlSelect('cooledby_user', 'coolwriteups', 'coolwriteups_id='.$cid.' and cooledby_user = '.$uid.' limit 1') || 0 );

  --$$VARS{cools} unless $forceAllow;
  setVars($USER, $VARS); #Discount chings right away before anything else.

  $APP->adjustExp($$COOL{author_user}, 20);
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

  return;
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

  return unless $SRC->{type}->{title} eq "usergroup";
  return unless Everything::isApproved($USER, $SRC);

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

  if ($$SRC{title} eq 'News')
  {
    htmlcode('addNotification', 'frontpage', 0, { frontpage_item_id => getId($N) });
  }

  return;
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
sub massacre
{
  # Legacy opcode that exists because unpublishwriteup links to it for the security monitor. Disabling the page, then will swing back around to clean this out
  return;
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
  return;
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
  return;
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

  return;
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

  return;
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

  return;
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
  return;
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
      $APP->securityLog(getNode("Recent Node Notes","superdoc"), $USER, "removed note on [$$NOTEFOR{title}]");
    }
  }

  htmlcode('addNodenote', $notefor, $notetext, $USER) if $notetext;
  return;
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
  return;
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
  return;
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
    $APP->devLog("Hiding writeup: ".$query->param('hidewriteup'));
    my $writeup = int($query->param('hidewriteup'));
    $DB->sqlUpdate('newwriteup', { notnew=>'1' }, "node_id=$writeup");
    getRef $writeup;
    $$writeup{notnew} = 1;
    $DB->updateNode($writeup, -1);
    htmlcode('addNodenote', $writeup, "Hidden by $$USER{title}");
  }else{
    $APP->devLog("In hidewriteup: Can't figure out what writeup to hide");
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

sub changewucount
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '' if ( $APP->isGuest($USER) );

  if($query->param('amount'))
  {
    my $amount = $query->param('amount');
    if($amount =~ /^(\d+)$/)
    {
      $amount=$1;
      $amount = 50 if $amount > 50 ;
      $$VARS{num_newwus}=$amount;
    }
  }

  if ( $query->param( 'nw_nojunk' ) )
  {
    $$VARS{ nw_nojunk } = 1 ;
  } else {
    delete $$VARS{ nw_nojunk } ;
  }

  return 1;
}

sub repair_e2node
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $repair_id = $query->param('repair_id');
  my $no_order = $query->param('noorder');
  return unless $repair_id;

  my $result = htmlcode('repair e2node', $repair_id, $no_order);
  return 1 if $result;
  return;
}

sub borg
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # borgs the current node 1 time (iff current node is a user and current user is an admin)
  # N-Wing, Friday, May 24, 2002

  my $userid = $$USER{node_id};

  return unless $APP->isAdmin($USER);
  return unless $query->param('borgvictim');
  my $victimID = $query->param('borgvictim') || 0;
  return unless $victimID =~ /^(\d+)$/;
  my $victim = getNodeById($victimID=$1) || undef;
  return unless defined $victim;
  return unless $$victim{type}{title} eq 'user';

  my $borgSelf = $victimID==$userid;

  # following ripped from [message] (opcode)
  my $V = $borgSelf ? $VARS : getVars($victim);
  ++$$V{numborged};
  $$V{borged}=time;
  setVars($victim,$V) unless $borgSelf;
  $query->param('borgcount'.$victimID,$$V{numborged}); #shown in [admin toolset]

  $DB->sqlUpdate('room',{borgd=>'1'},'member_user='.$victimID);

  return;
}

sub flushcbox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
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

  $APP->securityLog(getNode('flushcbox', 'opcode'), $USER, "Chat $currentRoomName flushed.");
  $DB->sqlDelete("message", "for_user = 0 AND room = $currentRoomId");
  return 1;
}

sub repair_e2node_noreorder
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $repair_id = $query->param('repair_id');
  my $no_order = 1;
  return unless $repair_id;

  my $result = htmlcode('repair e2node', $repair_id, $no_order);
  return 1 if $result;
  return;

}

sub orderlock
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $N = getNodeById($query->param('node_id'));

  return unless $N;
  return unless $$N{type}{title} eq "e2node";

  if($query->param("unlock"))
  {
    $N->{orderlock_user} = 0;
  }else{
    $N->{orderlock_user} = $USER->{node_id};
  }

  updateNode($N, -1);
  return;
}

sub pollvote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);

  my $pollId = $query -> param('poll_id');
  my $vote = $query->param('vote');

  my $N = getNodeById($pollId);
  my @options = split /\n\s*/s, $$N{doctext};
  my @result_array = split(',', $$N{e2poll_results});
  return unless $N  && $$N{type}{title} eq 'e2poll' && $$N{poll_status} ne 'new' && $$N{poll_status} ne 'closed'
    && exists($options[$vote]);

  return if $DB->sqlSelect( # has already voted on this poll
    'pollvote_id'
    , 'pollvote'
    , "voter_user=$$USER{node_id} AND pollvote_id=$$N{node_id}");

  return unless $DB->sqlInsert('pollvote', { # don't update the poll if the vote gets lost
    pollvote_id => $pollId
    , voter_user => $$USER{node_id}
    , choice => $vote
    , -votetime => 'NOW()'});

  $result_array[$vote]++;
  my $votesum = undef;
  foreach ( @result_array )
  {
    $votesum = $votesum + $_;
  }

  $DB->sqlUpdate("e2poll", {
    e2poll_results => join(',', @result_array)
    , totalvotes => $votesum}
    , "e2poll_id=$pollId");

  return;
}

sub softlock
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $query->param("lockID");
  return unless $APP->isEditor($USER);

  my $lockNode = getNodeById($query->param("lockID"));
  return unless $lockNode;

  my $nodeReason = $query->param('nodelock_reason') || '';

  my $isLocked = $DB->sqlSelect("nodelock_node", "nodelock", "nodelock_node=$$lockNode{node_id} limit 1") || 0;

  if ($isLocked)
  {
    $DB->sqlDelete("nodelock","nodelock_node=$$lockNode{node_id}");
  } else {
    $DB->sqlInsert("nodelock", {nodelock_reason => $nodeReason, nodelock_user => $$USER{user_id}, nodelock_node => $$lockNode{node_id}});
  }

  return;
}

sub weblogify
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $disp = $query->param("ify_display");
  my $nid =  $query->param("node_id");
  return unless $disp;
  return unless $disp gt '';

  my $wl = getNode('webloggables','setting');

  my $wSettings = getVars($wl);

  $$wSettings{$nid} = $disp;

  setVars($wl, $wSettings);

  my $N = getNodeById($nid);
  getRef $N;

  if($$N{group})
  {
    my $GROUP = $$N{group};
    my @memberIDs = @$GROUP;
    foreach(@memberIDs)
    {
      my $u = getNodeById($_);
      next unless $u;
      my $v =getVars($u);
      next if ($$v{can_weblog} =~ /$nid/);
      if (length($$v{can_weblog}) ==0 )
      {
        $$v{can_weblog} = $nid;
      } else {
        $$v{can_weblog} = $$v{can_weblog} .",".$nid;
      }

      if ($_ == $$USER{user_id})
      {
        $VARS = $v;
      }

      setVars($u,$v);
    }
  }

  return;
}

sub leadusergroup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $uName = $query->param("new_leader");
  my $userGroup = $query->param("node_id");

  return unless $uName;
  return unless $userGroup;

  my $recUser = getNode($uName,"user");
  if (!$recUser)
  {
    $uName =~ s/\_/ /gs;
    $recUser = getNode($uName, 'user');
  }

  return unless $recUser;
  return unless $APP->inUsergroup($recUser,getNodeById($userGroup));

  my $auth = $USER;
  $auth = -1 if $APP -> getParameter($userGroup, 'usergroup_owner') == $USER -> {node_id};
  $APP -> setParameter($userGroup, $auth, 'usergroup_owner', $recUser -> {node_id});

  return 1;
}

sub ilikeit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isSpider();
  my $nid = $query->param("like_id");
  return unless $nid;

  my $LIKE = getNodeById($nid);
  return unless $LIKE;

  my $addr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR} || undef;
  return if $DB->sqlSelect("count(*)","likedit","likedit_ip = '$addr' and likedit_node=$nid");
 
  my $GU = $Everything::CONF->guest_user;

  my $lType = getNode("ilikeit","linktype")->{node_id};

  my $linkExists = $DB->sqlSelect("count(*)","links","from_node=$GU and to_node=$nid and linkType = $lType");
  if ($linkExists)
  {
    $DB->sqlUpdate("links",{-hits => 'hits + 1'},"from_node=$GU and to_node=$nid and linkType = $lType");
  } else {
    $DB->sqlInsert("links",{from_node => $$USER{user_id}, to_node => $nid, linktype => $lType});
  }

  return if ($$LIKE{author_user} == getId(getNode('Webster 1913', 'user')));

  my $logQueryLikeIt = qq|
    INSERT INTO likeitlog
    (user_agent, liked_node_id, hits)
    VALUES
    (?, ?, ?)
    ON DUPLICATE KEY UPDATE
    hits=hits+1|;
 
  $DB->getDatabaseHandle()->do($logQueryLikeIt, undef , $ENV{HTTP_USER_AGENT}, $nid, 1);

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time - 86400*30);
  $year += 1900;
  $mon++;
  if ($mon ==12)
  {
    $mon = 1;
  }

  my $checkDate = sprintf('%02d-%02d-%02d',$year,$mon,$mday);

  my $isRecent = (getNodeById($$LIKE{author_user})->{lasttime} ge  $checkDate);

  my $likeVars = getVars(getNodeById($$LIKE{author_user}));
  my $notifyMe = (!($$likeVars{no_likeitnotification}));

  if (($isRecent) && ($notifyMe))
  {
    my $msgText = 'Hey, sweet! Someone likes your writeup titled "[' . getNode($$LIKE{parent_e2node})->{title} . ']!"';

    $DB->sqlInsert('message',{
      'msgtext' => , $msgText,
      'author_user' => getId(getNode('Cool Man Eddie', 'user')),
      'for_user' => $$LIKE{author_user},
      'for_usergroup' => 0,
      'archive' => 0 });
  }

  $DB->sqlInsert('likedit',{likedit_ip => $addr, likedit_node => $$LIKE{node_id}});
  return;
}

sub changeusergroup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Changes which usergroup is selected for the Usergroup Writeups nodelet.

  if($query->param('newusergroup'))
  {
    my $newUsergroup = $query->param('newusergroup');
    $$VARS{nodeletusergroup}=$newUsergroup;
  }

  return 1;
}

sub favorite
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $node_id = $query -> param("fave_id");
  my $fav = getNodeById($node_id);
  return if $fav -> {type_nodetype} != getType("user") -> {node_id};
  return if $APP->isGuest($USER);
  my $LINKTYPE = getNode('favorite', 'linktype');

  $DB->sqlInsert('links', {-from_node => getId($USER), -to_node => $node_id, -linktype => getId($LINKTYPE)});
  return;
}

sub unfavorite
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $node_id = $query -> param("fave_id");
  my $fav = getNodeById($node_id);
  return if $fav -> {type_nodetype} != getType("user") -> {node_id};
  return if $APP->isGuest($USER);
  my $LINKTYPE = getNode('favorite', 'linktype');

  my $uid = $$USER{'node_id'};

  $DB->sqlDelete('links', "from_node = $uid AND to_node = $node_id AND linktype = $$LINKTYPE{node_id}");
  return;
}

sub category
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);
  my $isCE = $APP->isEditor($USER);
  return if ($APP->getLevel($USER) <= 1) && !$isCE;

  my $cid = $query->param('cid');
  if ($cid eq 'new' and my $title = $query -> param('categorytitle'))
  {
    $cid = $DB -> insertNode($APP->cleanNodeName($title), 'category', $USER);
    $query -> param('cid', $cid) if $cid;
  }
  $cid = int $cid;
  return unless $cid;

  my $nid = int($query->param('nid'));
  $nid ||= int($query->param('node_id'));
  $nid ||= 0;
  return unless $nid;

  #don't let users link the category to itself
  return if ($cid == $nid);

  my $nodeToLink = getNodeById($nid);
  my $category = getNodeById($cid);
  return unless $nodeToLink && $category;

  my $maintainer = getNodeById($$category{author_user});

  # validate the maintainer nodetype
  if ($$maintainer{type}{title} eq 'user')
  {
    # if category author is not current user or guest user
    # and the user is not an admin or CE, quit
    if($$maintainer{node_id} != $$USER{user_id} && !$APP->isGuest($$maintainer{node_id}) && !$isCE)
    {
      return 0;
    }
  } elsif ($$maintainer{type}{title} eq 'usergroup')
  {
    if(!$APP->inUsergroup($USER, $maintainer) && !$isCE)
    {
      return 0;
    }
  } else {
    # category author must be a user or usergroup
    return 0;
  }

  my $LINKTYPE = getNode('category', 'linktype');

  # if the node to be linked is a writeup, make sure the writeup's parent e2node is not already linked
  return if $$nodeToLink{type}{title} eq 'writeup' and $DB -> sqlSelect(
    'to_node'
    , 'links'
    , "from_node=$$category{node_id} AND to_node=$$nodeToLink{parent_e2node} AND linktype=$$LINKTYPE{node_id}");

  # don't allow dups
  return if $DB -> sqlSelect(
    'to_node'
    , 'links'
    , "from_node=$$category{node_id} AND to_node=$nid AND linktype=$$LINKTYPE{node_id}" );

  # if we've passed all these checks, go ahead and add the link
  $DB->sqlInsert('links', {
    from_node => $cid
    , to_node => $nid
    , linktype => getId($LINKTYPE)
    , -food => "(SELECT IFNULL(MAX(food) + 10, 0) 'food'
    FROM links AS l WHERE from_node = $cid)"});
  return 1;

}

sub socialBookmark
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
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

sub sanctify
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if ($$VARS{GPoptout});

  my $minLevel = 11;
  my $Sanctificity = 10;
  return unless $APP->getLevel($USER)>= $minLevel;

  my $U = $query->param('node_id');
  $U = getNode($query->param("node"), 'user') if ($query->param('node'));
  getRef $U;

  return unless $$U{type}{title} eq 'user';

  $$U{sanctity} += 1;
  updateNode($U, -1);

  $APP->adjustGP($U, $Sanctificity);
  $APP->adjustGP($USER, -$Sanctificity);
  $$VARS{oldGP} = $$USER{GP};

  $APP->securityLog(getNode('Sanctify user', 'superdoc'), $USER, "$$USER{title} sanctified $$U{title} with $Sanctificity GP.");

  htmlcode('sendPrivateMessage',{
    'author_id' => getId(getNode('Cool Man Eddie', 'user')),
    'recipient_id' => $$U{user_id},
    'message' => "Whoa! You’ve been [Sanctify|sanctified]!" });

  return;
}

sub movenodelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # See htmlcode for useful info on parameters
  htmlcode('movenodelet',$query->param('nodelet'),$query->param('position'));
  return;
}

sub cure_infection
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 0 unless $APP->isAdmin($USER) || !htmlcode('verifyRequest', 'cure_infection');

  my $cureUserId = int($query->param("cure_user_id"));
  my $cureUser = getNodeById($cureUserId);
  return 0 unless $cureUser && $$cureUser{type}{title} eq 'user';

  my $cureVars = getVars($cureUser);
  $$cureVars{infected} = 0;
  setVars($cureUser, $cureVars);

  return 1;
}

sub publishdrafttodocument
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
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
  my $PAGELOAD = shift;
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

sub parameter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $paramname = $query->param('paramname');
  my $paramvalue = $query->param('paramvalue');
  my $action = $query->param('action');
  my $for_node = $query->param('for_node');

  if(not defined($for_node))
  {
    $for_node ||= $NODE;
  }

  $DB->getRef($for_node);

  if($action ne "delete")
  {
    $APP->setParameter($for_node, $USER, $paramname, $paramvalue);
  }else{
    $APP->delParameter($for_node, $USER, $paramname);
  }

  return;
}

sub remove
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
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
