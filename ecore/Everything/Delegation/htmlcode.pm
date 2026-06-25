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
  # *canUpdateNode alias removed with publishwriteup, its only user in this file (#4354)
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

# publishwriteup REMOVED - the legacy form-post publish flow is retired (#4354).
# Writeups are now published by converting a draft in
# Everything::API::drafts::publish_draft (a node-type sqlUpdate that skips
# maintenance). The writeup_create maintenance hook no longer calls this; it now
# only guards against out-of-band writeup creation.
# nodepack/htmlcode/publishwriteup.xml deleted; prod node 2036500 nuked.

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

# nopublishreason REMOVED - the publish-permission gate for the dead form-post
# flow (#4354). The live publish path (Everything::API::drafts::publish_draft)
# enforces its own ownership / duplicate / lock checks.
# nodepack/htmlcode/nopublishreason.xml deleted; prod node 2036363 nuked.

# canpublishas REMOVED - migrated to Everything::Application::publishas_accounts
# and ::can_publish_as, surfaced by the React publish-as picker through
# Everything::API::drafts (publishas_options + publish_draft's publish_as) (#4354).
# nodepack/htmlcode/canpublishas.xml deleted; prod node 2055136 nuked.

# addNodenote REMOVED - now Everything::Application::add_nodenote
# ($APP->add_nodenote); its maintenance callers (node_forward_create,
# draft_update) were repointed. #4354

# unpublishwriteup REMOVED - now Everything::Application::unpublish_writeup
# ($APP->unpublish_writeup($USER, $wu, $reason)); the writeup-lifecycle
# maintenance hooks (writeup_update / e2node_delete / writeup_delete) were
# repointed. #4354

# blacklistedIPs REMOVED - Dead code, IP blacklist display migrated to React Page class. Jan 2026.

# resurrectNode REMOVED - orphaned by the resurrect opcode removal (API uses $DB->resurrectNode). Jun 2026.

# reinsertCorpse REMOVED - orphaned by the resurrect opcode removal. Jun 2026.

1;
