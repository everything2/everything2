package Everything::Delegation::htmlcode;
use Everything::SecurityLog qw(:events);

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

## Until all of the evals are dead, this is a strict necessity
## no critic (ProhibitStringyEval)

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
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *getPageForType = *Everything::HTML::getPageForType;
}

# Used by parsetime, parsetimestamp, timesince, giftshop_buyching 
use Time::Local;

# Used by shownewexp, publishwriteup, hasAchieved, showNewGP, sendPrivateMessage
use JSON;

# Used by hasAchieved for achievement delegation
use Everything::Delegation::achievement;

# Used by Application::getRenderedNotifications for notification rendering
use Everything::Delegation::notification;

# Used by retrieveCorpse for safe deserialization
use Everything::Serialization qw(safe_deserialize_dumper);

# Used by publishwriteup,isSpecialDate
use DateTime;

# Used by publishwriteup
use DateTime::Format::Strptime;

# Used by uploaduserimage, giftshop_buyching
use POSIX qw(strftime ceil floor);
use File::Copy;
use Image::Magick;


# Used by create_short_url;
use POSIX;

# called from [writeup maintenance create] (formerly also the retired publishdraft opcode, #4320)
# we have already checked that everything exists,
# and that this user can publish this writeup to this node
#
sub publishwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($WRITEUP, $E2NODE) = @_;

  my $WRTYPE = getNodeById(scalar($query->param('writeup_wrtype_writeuptype')));
  # if we haven't been given a type, use the default:
  $WRTYPE = getNode('thing', "writeuptype") unless $WRTYPE and $$WRTYPE{type}{title} eq 'writeuptype';

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  my $notnew = $query->param("writeup_notnew") || 0;

  # some of this should theoretically happen automatically. But sometimes fails. So:
  $$WRITEUP{parent_e2node} = getId $E2NODE;
  $$WRITEUP{wrtype_writeuptype} = getId $WRTYPE;
  $$WRITEUP{notnew} = $notnew;
  $$WRITEUP{title} = "$$E2NODE{title} ($$WRTYPE{title})";
  $$WRITEUP{hits} = 0; # for drafts
  $$WRITEUP{publishtime} = $$E2NODE{updated} = sprintf '%4d-%02d-%02d %02d:%02d:%02d', $year+1900,$mon+1,$mday,$hour,$min,$sec;

  $DB->sqlInsert('newwriteup', {node_id => getId($WRITEUP), notnew => $notnew});

  # If you are publishing as another user, and you have permission to, let this go through.
  if($WRITEUP->{author_user} != $USER->{node_id} && htmlcode("canpublishas",getNodeById($WRITEUP->{author_user})->{title}))
  {
    $DB->updateNode($WRITEUP, -1);
  }else{
    unless($DB->updateNode($WRITEUP, $USER))
    {
      Everything::printLog("In publishwriteup, user '$$USER{title}' Could not update writeup id: '$$WRITEUP{node_id}'"); 
    }
  }

  $DB->updateNode($E2NODE, -1);

  unless ($$WRTYPE{title} eq 'lede'){
    # insert into the node group, last or before Webster entry;
    # make sure Webster is last while we're at it
	
    my @addList = $DB->getNodeWhere({
      parent_e2node => $$E2NODE{node_id},
      author_user => getId(getNode('Webster 1913', 'user'))
      }, 'writeup');
	
    removeFromNodegroup($E2NODE, $addList[0], -1) if @addList; # remove Webster
	
    unshift @addList, $WRITEUP;
    insertIntoNodegroup($E2NODE, -1, \@addList);
  }else{
    # insert at top of node group
    insertIntoNodegroup($E2NODE, -1, $WRITEUP, 0);
  }

  # No XP, writeup count, notifications or achievement for maintenance nodes
  if ( $APP->isMaintenanceNode($E2NODE) ){
    return;
  }

  return if $$WRITEUP{author_user} != $$USER{node_id}; # no credit for publishas

  # credit user
  $$USER{experience}+=5;
  $DB->updateNode($USER, $USER);

  $$VARS{numwriteups}++;
  $$VARS{lastnoded} = $$WRITEUP{writeup_id};

  $APP->checkAchievementsByType('writeup', $$USER{user_id});

  # Inform people who have this person as one of their favorite authors
  my $favoriteNotification = getNode("favorite","notification")->{node_id};
  my $favoriteLinkType = getNode("favorite","linktype")->{node_id};
  my $faves = $DB->sqlSelectMany(
    "from_node",
    "links",
    "to_node = $$USER{user_id} AND linktype= $favoriteLinkType");

  while (my $f = $faves->fetchrow_hashref){
    my $fVars = getVars(getNodeById($$f{from_node}));
    if ($$fVars{settings}) 
    {
      if (from_json($$fVars{settings})->{notifications}->{$favoriteNotification})
      {
        my $argSet = { writeup_id => getId($WRITEUP),
          favorite_author => $$USER{user_id}};
        my $argStr = to_json($argSet);
        my $addNotifier = htmlcode('addNotification',
          $favoriteNotification, $$f{from_node},$argStr);
      }
    }
  }

  # Determine if this is a user created in the last two weeks
  my $dateParser = new DateTime::Format::Strptime(
    pattern => '%F %T',
    locale  => 'en_US',
  );

  # This only really doesn't happen in the test environment
  if(my $createTime = $dateParser->parse_datetime($$USER{createtime}))
  {
    my $userAge = DateTime->now()->subtract_datetime($createTime);
    my $youngAge = DateTime::Duration->new(days => 14);
    my $isYoungin = (DateTime::Duration->compare($userAge, $youngAge) < 0 ? 1 : 0);

    # Make a notification about a newbie writeup

    if($$VARS{numwriteups} == 1 || $isYoungin)
    {
      htmlcode('addNotification' , "newbiewriteup", undef,
        {
          writeup_id => getId($WRITEUP),
          author_id => $$USER{user_id},
          publish_time => DateTime->now()->strftime("%F %T")
        }
      );
    }
  }

  return $query->param('publish', 'OK');

}

# weblog htmlcode REMOVED - orphaned legacy weblog display (rendered op=removeweblog remove-links); htmlcode('weblog') invoked nowhere, node 458113 unreferenced. Modern path: Controller/usergroup + React + API::weblog. #4310. Jun 2026.

# verifyRequestHash + verifyRequest REMOVED - they were the nonce generator +
# checker for the legacy gotoNode node-update-via-URL form (rendered by the now-
# dead `openform`). That form + its only other callers (the_old_hooked_pole,
# everything_s_most_wanted) are gone, and the gotoNode update block was removed,
# so both are caller-free. #4198

# sendPrivateMessage REMOVED - this ~796-line htmlcode was the last duplicate of
# Everything::Application::sendPrivateMessage, which already owned the real
# implementation (cool/costumes/giftshop/admin/users/easter_eggs/tokenator + the
# API layer all call $APP->sendPrivateMessage). The final two callers (the debate-
# comment reply notify + the new-discussion announce in Delegation::maintenance)
# were repointed to $APP->sendPrivateMessage; the usergroup announce from the
# Virgil bot uses the new sendUsergroupMessage bypass_membership option (legacy
# gated group sends on the acting user, who was always a member there).
# nodepack/htmlcode/sendprivatemessage.xml deleted too. #4349

# screens notelet text
# reads "raw" and writes "screened"
#
sub screenNotelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my $work = $VARS->{'noteletRaw'} || $VARS->{'personalRaw'};
  delete $VARS->{'personalRaw'};

  my $UID = getId($USER) || 0;
  # not filtering, since only shown for user that enters the stuff anyway

  ##only allow certain HTML tags through
  #my $HTMLS = getVars(getNode('approved HTML tags','setting'));

  ##allow a few other tags and attributes
  ##TODO? others?
  #$HTMLS->{'table'} = 'border,cellpadding,cellspacing';
  #$HTMLS->{'th'} = $HTMLS->{'tr'} = $HTMLS->{'td'} = 1;

  #TODO? allow eds to psuedoExec
  #TODO? allow admins to have normal code

  #$work =~ s/\<!--.*?--\>//gs;	#$APP->htmlScreen messes up comments
  #$work = $APP->htmlScreen($work, $HTMLS);	#we may get rid of this later

  unless($VARS->{noteletKeepComments})
  {
    $work =~ s/<!--.*?-->//gs;
  }

  # length is limited based on level
  my $maxLen = $APP->getLevel($USER) || 0;
  $maxLen *= 100;
  if($maxLen>1000)
  {
    $maxLen=1000;
  } elsif($maxLen<500) {
    $maxLen=500;
  }

  # power has its privileges
  # this is in [Notelet Editor] (superdoc) and [screenNotelet] (htmlcode)
  if($APP->isAdmin($USER))
  {
    $maxLen = 32768;
  } elsif( $APP->isEditor($USER) ) {
    $maxLen += 100;
  } elsif($APP->isDeveloper($USER) ) {
    $maxLen = 16384; #16k ought to be enough for everyone. --[Swap]
  }

  if(length($work)>$maxLen)
  {
    $work=substr($work,0,$maxLen);
  }

  # N-Wing added 2003.08.20.n3 to deal with an unclosed comment
  # preventing a user from editing the notelet later
  if($work =~ /^(.*)<!--(.+?)$/s)
  {
    my $preLastComment = $1;
    my $postLastComment = $2;
    if($postLastComment !~ /-->/s)
    {
      # oops, unclosed comment; display it instead
      $work = $preLastComment . '<code>&lt;!--</code>' . $postLastComment;
    }
  }

  delete $VARS->{'personalScreened'};	#old way

  # Strip <script> tags to prevent user scripts from breaking React pages
  $work =~ s/<script[^>]*>.*?<\/script>//gis;
  $work =~ s/<script[^>]*>//gis;  # Also catch unclosed script tags
  $work =~ s/<\/script>//gis;     # Also catch stray closing tags

  if(length($work))
  {
    $VARS->{'noteletScreened'} = $work;
  } else {
    delete $VARS->{'noteletScreened'};
  }

  return;

}

#
# possibly forms a link to external web site
# URL must start with the protocol, http:// or https://
#
# externalLinkDisplay REMOVED - Dead code, external links now handled in React. Jan 2026.

# softlock htmlcode - REMOVED January 2026: No callers found

sub atomiseNode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my $host = $ENV{HTTP_HOST} || $Everything::CONF->canonical_web_server || "everything2.com";
  $host = "http://$host" ;

  my $atominfo = sub {
    my $N = shift ;
    my $url = $host . urlGen({ }, 'noQuotes', $N) ;
    my $author = getNodeById( $$N{author_user} ) ;
    my $authorurl = $host . $APP -> urlGenNoParams($author, 'no quotes') ;
    my $timestamp = $$N{publishtime} || $$N{createtime};
    $timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
    $timestamp = sprintf ("%04d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $4, $5, $6);
	
    return '<title>' . $APP->encodeHTML($$N{title}) . '</title>' .
      '<link rel="alternate" type="text/html" href="' . $url . '"/>' .
      '<id>' . $url . '</id>' .
      '<author>' .
      '<name>' . $$author{ title } . '</name>' .
      '<uri>' . $authorurl . '</uri>' .
      '</author>' .
      '<published>'. $timestamp . '</published>' .
      '<updated>'. $timestamp . '</updated>' ;
  };

  my ( $input , $length ) = @_ ;
  $length ||= 1024 ;

  # Inlined the only slice of [show content] the feeds used: wrap each node in
  # <entry>, emit the atominfo metadata, then render doctext through the link
  # parser, truncated to $length. show_content's full-page rendering breadth was
  # unused here; it is retired with this change. #4345
  my @input = ( $input ) ;
  if ( ref $input eq 'ARRAY' ) {
    @input = @$input ;
  } elsif ( ref( $input ) =~ /DBI/ ) {
    @input = @{ $input->fetchall_arrayref( {} ) } ;
  }
  return '' unless getRef( @input ) ;

  my $showanyway = 96 ; # too few bytes to bother truncating
  my $HTML = getVars( getNode( 'approved HTML tags' , 'setting' ) ) ;

  # parseLinks/screenTable target derives from the PAGE node (this mirrors
  # [show content], which read the global $NODE, not each entry). For the feeds
  # the page node is the feed node, so this is undef and links carry no
  # lastnode_id -- matching the prior output exactly.
  my $lastnodeid = undef ;
  unless ( $APP->isGuest( $USER ) ) {
    $lastnodeid = $$NODE{ parent_e2node } if $$NODE{ type }{ title } eq 'writeup' ;
    $lastnodeid = $$NODE{ node_id } if $$NODE{ type }{ title } eq 'e2node' ;
  }

  my $str = '' ;
  foreach my $N ( @input ) {
    my $text = $$N{ doctext } ;
    $text = $APP->breakTags( $text ) ;

    my $dots = '' ;
    if ( $length && length( $text ) > $length + $showanyway ) {
      $text = substr( $text , 0 , $length ) ;
      $text =~ s/\[[^\]]*$// ; # broken links
      $text =~ s/\s+\w*$// ;   # broken words
      $dots = '&hellip;' ;
    }

    $text = $APP->screenTable( $text ) if $lastnodeid ;
    $text = parseLinks( $APP->htmlScreen( $text , $HTML ) , $lastnodeid ) ;
    $text =~ s/<a .*?(href=".*?").*?>/<a $1>/sg ; # kill onmouseup etc

    $str .= '<entry>' . $atominfo->( $N ) . "\n"
      . '<content type="html">' . $APP->encodeHTML( $text . $dots ) . '</content>' . "\n"
      . '</entry>' ;
  }

  return $str ;
}

sub userAtomFeed
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($foruser) = @_;
  return unless $foruser;

  $foruser =~ s/&#39;/'/g;
  my $u = getNode($foruser, 'user');
  return unless $u;

  my $csr = $DB->sqlSelectMany('node.node_id, publishtime',
    'node JOIN writeup on node_id=writeup_id',
    'author_user=' . getId($u) .
    ' order by publishtime desc limit 6');

  # this is so we have the first result for the timestamp
  my $row = $csr->fetchrow_hashref;
  return unless $row;
  my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  $str .= "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:base=\"http://everything2.com/\">\n";
  $str .= "    <title>" . $foruser . "'s New Writeups</title>\n";
  $str .= "    <link rel=\"alternate\" type=\"text/html\" href=\"http://everything2.com/index.pl?node=Everything%20User%20Search&amp;usersearch=" . $foruser . "\" />\n";
  $str .= "    <link rel=\"self\" type=\"application/atom+xml\" href=\"?node=New%20Writeups%20Atom%20Feed&amp;type=ticker&amp;foruser=" . $foruser . "\" />\n";
  $str .= "    <id>http://everything2.com/?node=New%20Writeups%20Atom%20Feed&amp;foruser=" . $foruser . "</id>\n";

  my $timestamp = $$row{publishtime};   
  $timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
  $timestamp = sprintf ("%04d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $4, $5, $6);
   
  $str .= "    <updated>$timestamp</updated>\n";

  do {
    $str .= htmlcode('atomiseNode', $$row{node_id});
  } while($row = $csr->fetchrow_hashref);

  $str.="</feed>\n";
  return $str;
}

# show_node_forward REMOVED - Dead code, node forward display migrated to React. Jan 2026.

# achievementsByType REMOVED - Dead code, achievements display migrated to React. Jan 2026.
# editor_homenode_tools REMOVED - Dead code, editor tools migrated to React. Jan 2026.

# coolcount REMOVED - factored into Everything::Application->coolcount (unit-tested). Jun 2026.

# epicenterZen REMOVED - Dead code, epicenter data now provided via Application.pm to React. Jan 2026.

sub addNotification
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  return $APP->add_notification(@_);
}

# isInfected REMOVED - Dead code, old infection game feature. Jan 2026.

# ip_lookup_tools REMOVED - Migrated to React UserToolsModal. Jan 2026.

# blacklistIP REMOVED - migrated to Everything::API::admin::_blacklist_ip. Its
# only caller, the_old_hooked_pole, now drives the mass cleanup through
# POST /api/admin/users/cleanup. #4198
# lock_user_account REMOVED - migrated to Everything::API::admin::_do_lock_account
# (shared by lock_user + the cleanup endpoint). #4198

# decode_short_string REMOVED - Dead code, replaced by Everything::Page::short_url_lookup. Jan 2026.
# create_short_url REMOVED - Dead code, replaced by Everything::Application::create_short_url. Jan 2026.

sub urlToNode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my $targetNode = shift;
  getRef $targetNode;

  my $bNoQuoteUrl = 1;
  my $urlParams = { };
  my $redirectPath = urlGen($urlParams, $bNoQuoteUrl, $targetNode);
  return 'http://' . $ENV{HTTP_HOST} . $redirectPath;
}

# weblogform htmlcode - REMOVED January 2026: React AddToWeblogModal + /api/weblog handles this
# categoryform htmlcode - REMOVED January 2026: React AddToCategoryModal + /api/category handles this
# widget REMOVED - Dead code, widget UI migrated to React. Jan 2026.

sub nopublishreason
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # find any reasons for a user not being able to post a writeup (to an e2node)
  # second argument is optional.
  # returns text of reason, existing writeup, or ''

  my ($user, $E2N) = @_;
  $user ||= $USER;
  getRef $user;
  getRef $E2N if $E2N;

  if( $APP->isGuest($USER) )
  {
    return parseLinks('[login[superdoc]|Log in] or [Sign Up[superdoc]|register] to write something here or to contact authors.');
  }

  # unverified email address:

  return parseLinks('You need to [verify your email account[superdoc]] before you can publish writeups.') if $APP->isSuspended($user, 'email');

  # already has a writeup here:

  my @group = (); @group = @{ $$E2N{group} } if $E2N and $$E2N{group};
  foreach (@group)
  {
    getRef($_);
    return $_ if $$_{author_user} == $$user{node_id};
  }

  # no more checks if author has an editor-approved a draft for this node:
  my $linktype = getId($DB->getNode('parent_node', 'linktype'));
  return '' if $E2N && $DB->sqlSelect(
    'food' # 'food' is the editor
    , 'links JOIN node ON from_node=node_id'
    , "to_node=$$E2N{node_id} AND linktype=$linktype AND node.author_user=$$user{node_id}");

  my $notMe = ($user->{node_id} ne $USER->{node_id});

  # user on forbiddance:

  my $userlock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$user{user_id}");
  $userlock = {} if !$userlock && $APP->isSuspended($user, 'writeup');

  return ($notMe ? 'User is' : 'You are')
    .' currently not allowed to publish writeups. '
    .parseLinks($$userlock{nodelock_reason}) if $userlock;

  # node is locked:

  my $nodelock = undef; $nodelock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$E2N{node_id}") if $E2N;
  return '' unless $nodelock;

  return 'This node is locked. '
    .parseLinks($$nodelock{nodelock_reason}
    .($notMe ? '' : '<p>If you feel you have something to add to this node, attach your
    [Drafts[superdoc]|draft] to it and set its status to "review" to 
    request review and release for publication here by an [Content Editors[usergroup]|editor].</p>'));
}

sub canpublishas
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # if an argument: return 1 if current user can publish under this name
  # if no argument: return a form control with names of accounts from which user can choose

  my $anonymousPublishLevel = 1; # users at or above this level can publish as 'everyone'
  my $target = shift;

  return '' unless($USER and not $APP->isGuest($USER) and $APP->getLevel($USER) >= $anonymousPublishLevel);

  my %accounts = (everyone => 1, Virgil => 'e2docs');

  @accounts{('Webster 1913', 'EDB', 'Klaproth', 'Cool Man Eddie')} = (1,1,1,1) if $APP->isEditor($USER);

  if ($target)
  {
    return '' unless $target;
    return 1 if $accounts{$target} == 1 or $DB->isApproved($USER, getNode($accounts{$target}, 'usergroup'));
    return '';
  }

  my @names = ();
  foreach (keys %accounts)
  {
    push @names, $_ if $accounts{$_} == 1 or $DB->isApproved($USER, getNode($accounts{$_}, 'usergroup'));
  }

  my $blah = '<br><small>N.B. By publishing to a different account you cede your copyright and lose all control over your writeup</small>';

  if (scalar @names == 1)
  {
    return $query -> checkbox(
      -name => 'publishas'
      , value => 'everyone'
      , label => "publish anonymously (as 'everyone')"
      ).$blah;

  } elsif(@names) {
    @names = sort {$a eq 'everyone' ? -1 : $b eq 'everyone' ? 1 : lc($a) cmp lc($b)} @names;
    return $query -> label(
      'publish as:'
      .$query -> popup_menu(
        -name => 'publishas'
        , -values => ['', @names]
        , default => ''
      )
    ).$blah;
  }

  return '';

}

sub addNodenote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($notefor, $notetext, $user) = @_;

  getRef $user;
  $notefor = getId $notefor;

  if($user)
  {
    $notetext="[$$user{title}\[user]]: $notetext";
    $user = $$user{user_id};
  }
  $user ||= 0;

  $DB->sqlInsert("nodenote", {
    nodenote_nodeid => $notefor
    , noter_user => $user
    , notetext => $notetext});

  my $nodenote_id = $DB->{dbh}->last_insert_id(undef, undef, qw(nodenote nodenote_id)) || 0;

  htmlcode('addNotification', 'nodenote', 0, {
    node_noter => $user
    , node_id => $notefor
    , nodenote_id => $nodenote_id}) if $user;

  return $nodenote_id;
}

sub unpublishwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($wu, $reason) = @_;

  getRef $wu;
  return unless $wu and $$wu{type}{title} eq 'writeup';

  return unless $$USER{node_id} == $$wu{author_user} or $APP->isEditor($USER);

  my $id = $$wu{node_id};
  my ($title, $noexp) = ($$wu{title}, 0);

  my $E2NODE = getNodeById($$wu{parent_e2node});

  if ($E2NODE)
  {
    $noexp = $APP->isMaintenanceNode($E2NODE);
    $title = $E2NODE -> {title};
  }elsif ($title =~ / \((\w+)\)$/ and getNode($1, 'writeuptype')){
    $title =~ s/ \((\w+)\)$//;
  }

  my $draftType = getType('draft');
  return 0 unless $DB -> sqlUpdate('node, draft', {
    type_nodetype => $draftType -> {node_id},
    title => $title,
    publication_status => getId(getNode('removed', 'publication_status'))},"node_id=$id AND draft_id=$id"
  );

  $$wu{title} = $title; # save possible fiddling elsewhere (e.g. in [remove])
  $$wu{type} = $draftType;
  $$wu{type_nodetype} = $draftType -> {node_id};
  delete $$wu{wrtype_writeuptype};

  $DB->sqlDelete('writeup', "writeup_id=$id");
  $DB->removeFromNodegroup($E2NODE, $wu, -1) if $E2NODE;

  $DB->{cache}->incrementGlobalVersion($wu); # tell other processes this has changed...
  $DB->{cache}->removeNode($wu); # and it's in the wrong typecache, so remove it

  $DB->sqlDelete('newwriteup', "node_id=$id");
  $APP->updateNewWriteups();

  $DB->sqlDelete('publish', "publish_id=$id");
  $DB->sqlDelete('links',
    "to_node=$id OR from_node=$id AND linktype=".getId(getNode('category', 'linktype')));

  my ($remover, $notification) = (undef,undef); my %editor = ();

  if ($$USER{node_id} == $$wu{author_user})
  {
    $remover = $notification = 'author';
  }else{
    $remover = "[$$USER{title}\[user]]";
    $notification = 'editor';
    %editor = (editor_id => $$USER{user_id});
  }

  htmlcode('addNotification', "$notification removed writeup", 0, {
    writeup_id => $$wu{node_id}
    , title => $$wu{title}
    , author_id => $$wu{author_user}
    , reason => $reason
    , %editor});

  $reason = defined($reason) && $reason ? ": $reason" : '';
  htmlcode('addNodenote', $wu, "Removed by $remover$reason");

  my $author = getNodeById($$wu{author_user});

  $APP->securityLog(SECLOG_MASSACRE, $USER, "[$title] by [$$author{title}] was removed$reason");

  unless($noexp)
  {
    $APP->adjustExp($$wu{author_user}, -5);

    my $vars = getVars $author;
    $$vars{numwriteups}--;
    $$author{numwriteups} = $$vars{numwriteups};

    setVars($author, $vars);
    updateNode($author, -1);
  }

  return 1;
}

# blacklistedIPs REMOVED - Dead code, IP blacklist display migrated to React Page class. Jan 2026.

# resurrectNode REMOVED - orphaned by the resurrect opcode removal (API uses $DB->resurrectNode). Jun 2026.

# reinsertCorpse REMOVED - orphaned by the resurrect opcode removal. Jun 2026.

1;
