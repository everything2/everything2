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

# Used by verifyRequestHash, getGravatarMD5, verifyRequest, verifyRequestForm
use Digest::MD5 qw(md5_hex);

# Used by uploaduserimage, giftshop_buyching
use POSIX qw(strftime ceil floor);
use File::Copy;
use Image::Magick;


# Used by create_short_url;
use POSIX;

# textarea REMOVED - Dead code, CGI textarea generator replaced by React forms. Jan 2026.

# windowview REMOVED - Dead code, no references found in database. Jan 2026.
# Was "pretty ancient" popup window generator.

# The mother of all display functions:
# generic content/contentinfo display
# arguments:
# 0. single hashref or node id, arrayref of node ids or hashrefs, sql cursor for node(s) to show
# 1. string containing comma-separated list of instructions:
#	(optional) 'xml' to specify xml output and/or
#	(optional) html tag, used for wrapping each node (attributes optional, quotes="double")
#		- default is <div>
#		- may include class attribute (which is added to default class(es))
#		- class tokens starting with & are interpreted as function names and executed on the node
#		- no default classes for xml, otherwise:
#		- default class is 'item' if content is included, otherwise 'contentinfo'
#			- div class 'contentinfo' also wraps headers/footers before and after content,
#			  with class 'contentheader' or 'contentfooter' as appropriate
#
#	and then/or:
#	list of fields to display, which can be:
#		* a function name, either a built-in mark-up function or an additional one passed in the next argument
#		* "text"
#		* a hash key to a value to be marked up as
#			- <span class="[key]>">value</span> (not xml) or
#			- <[key]>$APP->encodeHTML(value)</[key> (xml)
#		* 'content' to show the doctext
#		* 'unfiltered' to show the doctext without screening the html
#		* a number n, to display the first n bytes of the doctext
#	Multiple content/unfiltered/numbers can be specified one after the other, separated by '-':
#	they will be used in turn for successive items. The last one is used for any remaining items.
# 	If content is truncated and not xml a link is provided to the node in a div class="morelink"
#	If xml is specified content is encoded and wrapped as <content type="html">
# 2. (optional) additional markup functions
#	If one of these has the key 'cansee' it will be used to check whether to show an item:
#	return '1' for yes.
#
# Superdoc content is rendered via delegation
# tables in doctext are screened for logged-in users
#
sub show_content
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ( $input , $instructions , %infofunctions ) = @_ ;

  my $showanyway = 96 ; # how many bytes not to bother chopping off shortened content
  # pack/unpack input

  my @input = ( $input ) ;
  if ( ref $input eq 'ARRAY' ) {
    @input = @$input ;
  } elsif ( ref( $input ) =~ /DBI/ ) {
    @input = @{ $input->fetchall_arrayref( {} ) } ;
  }

  return '' unless getRef( @input );

  # define standard info functions

  my $getAuthor = sub{ $_[0]->{author} ||= getNodeById($_[0] -> {author_user}, 'light') || {}; } ;

  my $author = $infofunctions{author} ||= sub {
    linkNode( &$getAuthor , '' , {-class => 'author'}) ;
  } ;

  $infofunctions{ byline } ||= sub { '<cite>by '.&$author.'</cite>' ; } ;

  my $title = $infofunctions{ title } ||= sub {  linkNode($_[0] , '' , {-class => 'title'}) ; } ;

  $infofunctions{ parenttitle } ||= sub { 
    my $parent = getNodeById($_[0]{parent_e2node},'light'); 
    return '<span class="title noparent">(No parent node) '.&$title.'</span>' unless $parent ;
    my $localauthor = &$getAuthor;
    return linkNode($parent, '', {
      -class => 'title'
      , '#' => $$localauthor{title}
      , author_id => $$localauthor{node_id}
    });
  };

  $infofunctions{ type } ||= sub {
    my $type = $_[0]{type_title} || getNodeById($_[0]{wrtype_writeuptype}) || $_[0]{type};
    $type = $type->{title} if(UNIVERSAL::isa($type,"HASH"));
    if ($type eq 'draft'){
      my $status = getNodeById($_[0]{publication_status});
      $type = ($status ? $$status{title} : '(bad status)').' draft';
    }

    return '<span class="type">('.linkNode($_[0]{node_id}||$_[0]{writeup_id}, $type || '!bad type!').')</span>';
  };

  my $date = $infofunctions{date} ||= sub {
    return '<span class="date">'
      .htmlcode('parsetimestamp', $_[0]{publishtime} || $_[0]{createtime}, 256 + defined($_[1])?($_[1]):(0)) # 256 suppresses the seconds
      .'</span>' ;
  };

  $infofunctions{listdate} ||= sub{
    &$date($_[0], 4 + 512); # 4 suppresses day name, 512 adds leading zero to hours
  };

  my $oddrow = '';
  $infofunctions{oddrow} ||= sub{
    $oddrow = $oddrow ? '' : 'oddrow';
  };

  # decode instructions

  my $xml = 0;
  $xml = '1' if $instructions =~ s/^xml\b\s*// ;

  my ($wrapTag, $wrapClass, $wrapAtts) = ("", undef, undef);
  ($wrapTag, $wrapClass, $wrapAtts) = split(/\s+class="([^"]+)"/, $1) if $instructions =~ s/^\s*<([^>]+)>\s*//;

  $wrapAtts .= $1 if $wrapTag =~ s/(\s+.*)//;
  $wrapAtts ||= "";

  $instructions =~ s/\s*,\s*/,/g ;
  $instructions =~ s/(^|,),+/$1/g ; # remove spare commas

  my @sections = split( /,?((?:(?:content|[\d]+|unfiltered)-?)+),?/ , $instructions ) ;
  my $content = $sections[1] ;

  $wrapTag ||= 'div';
  $wrapClass .= ' ' if $wrapClass;
  $wrapClass .= $content ? 'item' : 'contentinfo';

  my @infowrap = ();
  @infowrap = ('<div class="contentinfo contentheader">', '', '<div class="contentinfo contentfooter">') if $content && !$xml;

  # define content function

  if ( $content ) {
    my $lastnodeid = undef;
    if ( !$APP->isGuest($USER) ) {
      $lastnodeid = $$NODE{ parent_e2node } if $$NODE{ type }{ title } eq 'writeup' ;
      $lastnodeid = $$NODE{ node_id } if $$NODE{ type }{ title } eq 'e2node' ;
    }

    my $HTML = getVars( getNode( 'approved HTML tags' , 'setting' ) ) ;
    my @content = split /-/, $content;
    my $i = 0;

    $infofunctions{$content} = sub {
      my $N = shift ;
      my $length = undef; $length = $content[$i] if $content[$i] =~ /\d/ ;
      $$HTML{ noscreening } = ($content[$i] eq 'unfiltered');
      $i-- unless $content[++$i];
      my $text = $N->{ doctext } ;

      # Superdocs now use React Page classes; doctext is empty for migrated superdocs
      $text = $APP->breakTags( $text ) ;

      my ( $dots , $morelink ) = ( '' , '' ) ;
      if ( $length && length( $text ) > $length + $showanyway ) {
        $text = substr( $text , 0 , $length );
        $text =~ s/\[[^\]]*$// ; # broken links
        $text =~ s/\s+\w*$// ; # broken words
        $dots = '&hellip;' ; # don't add here in case we still have a broken tag at the end
        $morelink = "\n<div class='morelink'>(". linkNode($$N{node_id} || $$N{writeup_id}, 'more') . ")\n</div>";
      }

      $text = $APP->screenTable( $text ) if $lastnodeid ; # i.e. if writeup page & logged in
      $text = parseLinks( $APP->htmlScreen( $text , $HTML ) , $lastnodeid ) ;
      return "\n<div class=\"content\">\n$text$dots\n</div>$morelink" unless $xml ;

      $text =~ s/<a .*?(href=".*?").*?>/<a $1>/sg ; # kill onmouseup etc
      return '<content type="html">'.$APP->encodeHTML( $text.$dots ).'</content>' ;
    };
  }

  # do it

  my $str = '';
  foreach my $N ( @input ) {
    next if $infofunctions{cansee} and $infofunctions{cansee}($N) != 1;

    my $class = ''; $class = qq' class="$wrapClass"' unless $xml;
    while ($class =~ m/\&(\w+)/) {
      my $intendedName = $1 ;
      my $intendedFunc = $infofunctions{ $intendedName } ;
      if ( $intendedFunc ) {
        $class =~ s/\&$intendedName/&$intendedFunc( $N )/e ;
      } else {
        $class =~ s/\&$intendedName/-Bad-info-function-'$intendedName'-/ ;
      }
    }

    $str .= qq'<$wrapTag$class$wrapAtts>';
    my $count = 0;

    foreach ( @sections ) {
      $str .= ($infowrap[$count] || "");
      my @chunks = split( /,+/ , $_ ) ;

      foreach ( @chunks ) {
        if ( exists( $infofunctions{ $_ } ) ) {
          $str .= $infofunctions{ $_ }( $N ) ;
        } elsif (/^"([^"]*)"$/){
          $str .= $1;
        } elsif ( $xml ) {
          $str .= "<$_>".$APP->encodeHTML( $$N{ $_ } )."</$_>" ;
        } else {
          my $value = $$N{ $_ } // '';
          $str .= "<span class=\"$_\">$value</span>" ;
        }

        $str .= "\n" ;
      }

      $str .= '</div>' if $infowrap[$count++];
    }
    $str .= "</$wrapTag>";
  }

  return $str ;
}

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

# [{parsetimestamp:time,flags}]
# Parses out a datetime field into a more human-readable form
# note: the expected time format in the parameter is: yyyy-mm-dd hh:mm:ss, although the year part works for any year after year 0
#	flags: optional flags:
#		1 = hide time (only show the date)
#		2 = hide date (only show the time)
#		4 = hide day of week (only useful if showing date)
#		8 = show 'UTC' (recommended to show only if also showing time)
#		16 = show full name of day of week (only useful if showing date)
#		32 = show full name of month (only useful if showing date)
#		64 = ignore user's local time zone settings
#		128 = compact (yyyy-mm-dd@hh:mm)
#		256 = hide seconds
#		512 = leading zero on single-digit hours
#
sub parsetimestamp
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($timestamp,$flags)=@_;
  $flags = ($flags || 0)+0;
  $timestamp //= '';
  my ($date, $time, $yy, $mm, $dd, $hrs, $min, $sec) = (undef,undef,undef,undef,undef,undef,undef,undef);

  if($timestamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/)
  {
    ($yy, $mm, $dd, $hrs, $min, $sec) = ($1, $2, $3, $4, $5, $6);
    #let's hear it for fudge:
    $mm-=1;
  }elsif($timestamp =~ / /)
  {
    ($date, $time) = split / /,$timestamp;

    ($hrs, $min, $sec) = split /:/, $time;
    ($yy, $mm, $dd) = split /-/, $date;
    $mm-=1;
  }

  # I repeat: let's hear it for fudge!
  return "<em>never</em>" unless (defined $yy && $yy =~ /^\d+$/ && int($yy)>0 && defined $mm && $mm =~ /^-?\d+$/ && int($mm)>-1 && defined $dd && $dd =~ /^\d+$/ && int($dd)>0);

  my $epoch_secs = timelocal( $sec, $min, $hrs, $dd, $mm, $yy);

  if(!($flags & 64) && $VARS->{'localTimeUse'}) {
    $epoch_secs += $VARS->{'localTimeOffset'} if exists $VARS->{'localTimeOffset'};
    #add 1 hour = 60 min * 60 s/min = 3600 seconds if daylight savings
    $epoch_secs += 3600 if $VARS->{'localTimeDST'};	#maybe later, only add time if also in the time period for that - but is it true that some places have different daylight savings time stuff?
  }

  my $wday = undef;
  ($sec, $min, $hrs, $dd, $mm, $yy, $wday, undef, undef) = localtime($epoch_secs);
  $yy += 1900;	#stupid Perl
  ++$mm;

  my $niceDate='';
  if(!($flags & 2)) {	#show date
    if ($flags & 128) { # compact
      $mm = substr('0'.$mm,-2);
      $dd = substr('0'.$dd,-2);
      $niceDate .= $yy. '-' .$mm. '-' .$dd;
    } else {
      if(!($flags & 4))
      {	
        #4=hide week day, 0=show week day
        $niceDate .= ($flags & 16)	#16=full day name, 0=short name
          ? (qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday))[$wday].', '
          : (qw(Sun Mon Tue Wed Thu Fri Sat))[$wday].' ';
      }

      my $fullMonthName = $flags & 32;
      $niceDate .= ($fullMonthName
        ? (qw(January February March April May June July August September October November December))
        : (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)))[$mm-1];

      $dd='0'.$dd if length($dd)==1 && !$fullMonthName;
      $niceDate .= ' ' . $dd;
      $niceDate .= ',' if $fullMonthName;
      $niceDate .= ' '.$yy;
    }
  }

  if(!($flags & 1)) {	#show time
    if ($flags & 128) { # if compact
      $niceDate .= '@' if length($niceDate);
    } else {
      $niceDate .= ' at ' if length($niceDate);
    }

    my $showAMPM='';
    if($VARS->{'localTime12hr'}) {
      if($hrs<12) {
        $showAMPM = ' AM';
        $hrs=12 if $hrs==0;
      } else {
        $showAMPM = ' PM';
        $hrs -= 12 unless $hrs==12;
      }
    }

    $hrs = '0'.$hrs if $flags & 512 and length($hrs)==1;
    $min = '0'.$min if length($min)==1;
    $niceDate .= $hrs.':'.$min;
    if (!($flags & 128 or $flags & 256)) { # if no compact show seconds
      $sec = '0'.$sec if length($sec)==1;
      $niceDate .= ':'.$sec;
    }	

    $niceDate .= $showAMPM if length($showAMPM);
  }

  $niceDate .= ' UTC' if length($niceDate) && ($flags & 8);	#show UTC

  return $niceDate;

}

# weblog htmlcode REMOVED - orphaned legacy weblog display (rendered op=removeweblog remove-links); htmlcode('weblog') invoked nowhere, node 458113 unreferenced. Modern path: Controller/usergroup + React + API::weblog. #4310. Jun 2026.

sub verifyRequestHash
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  #Generates a hashref used to verify the form submission. Pass a prefix.
  my ($prefix) = @_;
  my $rand = rand(999999999);
  my $nonce = md5_hex($$USER{passwd} . ' ' . $$USER{email} . $rand);

  return {$prefix . '_nonce' => $nonce, $prefix . '_seed' => $rand};
}

# sends a private message
#
# usage, examples, etc. in this node's "help" view:
#  ?node=sendPrivateMessage&type=htmlcode&displaytype=help
#
# TODO error condition for certain alias (me, I, anything else?) (maybe just hardcode in here, if a few)
# TODO if target is bot (use bot setting), see if they have a special htmlcode (probably best to run after did everything else)
#
# big big big big TODO: put this info into help displaytype ALSO 
# massive like OMG semi-trailer-truck-sized TODO: recode website; take tea when done
# big TODO:
#	How do we want to handle don't-send-to-self and auto-archive-when-sending-to-self ?
#	I've had 2 false starts that are specific to single-target, pseudo-group, and usergroup, but are pretty clumsy
#	I'm now thinking maybe doing something like msg-ignore: user can specify groups to do certain things to.
#
# thought #2: instead of making another table, since this is all user-based, we can just throw things into VARS
#	maybe: 'automsgsend_###' where ### is node_id of recipient (group or usergroup)
#	if multiple cases match, do one that keeps the most
#	bits:
#		0    1      if NOT set, ignore everything else, and use default settings
#		1-2  2,4,6  0=default, 2=always CC self, 4=never get self, 6=reserved
#		4    8      set archived flag, if happens to get message
#
# another thought: maybe change 'archive' field into 'folder' field; needs more thought: who create? who view? etc.
#
sub sendPrivateMessage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  #
  #parameters setup, part 1 of 2
  #

  my $params = shift;
  my $showWhatSaid = $params->{show_said};

  #
  #constants and global vars setup, part 1 of 2
  #

  my $UID = $USER->{node_id} || 0;

  return '' if $APP->isGuest($USER);
  return '' if $USER->{title} eq 'everyone';
  return 'Nothing to send: no message was given.' unless $params->{message};
  my $msg = $APP->messageCleanWhitespace($params->{message});
  return 'Nothing to send: message only consists of "whitespace" characters (for example, a space).' unless length($msg);

  my $cachedTitles = undef;
  my $cachedIDs = undef;

  #failure warning messages
  #these are always sent to the current user (which is not neccessarily the author we say the message is from)
  my @problems = ();
  #
  # subroutines
  #

  # returns if a parameter is set to 1 or not
  # if the given parameter exists and equals '1', then true is returned
  # any other condition will return false

  local *boolParam = sub {
    return (defined $_[0]) && (exists $params->{$_[0]}) && (defined $params->{$_[0]}) && ($params->{$_[0]} eq '1');
  };

  # gets a user or usergroup
  # pass ($title) to get based on title (respecting message deliver forwards)
  # pass ($id, 1) to get based on node ID
  # passed username should NOT be escaped
  ## this tries really hard to deal with names with spaces and/or underscores, and should get them, no matter how they are set up
  #note: do NOT optimize this to use the light-get, since then usergroups wouldn't have their group members loaded (this may be no longer true - does the UG auto code deal with this properly?)
  # updated: 2002.11.10.n0

  local *getCached = sub {
    my ($ident,$isNumeric) = (@_[0,1]);

    $isNumeric ||= 0;
    return unless defined($ident) && length($ident);

    my $N = undef;

    #get by ID
    if($isNumeric)
    {
      return unless $ident =~ /^(\d+)$/;
      $ident=$1;
      return $cachedIDs->{$ident} if exists $cachedIDs->{$ident};
      $N=getNodeById($ident);
      if(!$APP->isUserOrUsergroup($N))
      {
        undef $N;
      }

      if($N->{message_forward_to})
      {
        $N = getNodeById($N->{message_forward_to});
      }

      if((defined $N) && (exists $N->{title}) && length($N->{title}))
      {
        $cachedTitles->{$N->{title}} = $N;
      }

      $cachedIDs->{$ident} = $N;

      #get by title
    } else {
      if(exists($cachedTitles->{$ident}))
      {
        return $cachedTitles->{$ident} if exists $cachedTitles->{$ident};
      }
      # given title isn't cached, so find it
      # a forward address takes precedence over a real user

      my $forwarded = $ident;
      $N = getNode($forwarded,"usergroup") || getNode($forwarded,"user") || undef;
      unless($N)
      {
           $forwarded =~ s/_/ /g;
           $N = getNode($forwarded,"usergroup") || getNode($forwarded,"user") || undef;
      }

      unless($N)
      {
         # sendPrivateMessage getCached couldn't find object for forwarded, bailing
         return;
      }

      if($N->{message_forward_to})
      {
        $forwarded = $N->{title};
        $N = getNodeById($N->{message_forward_to});
      }

      # on 2002.11.09.n5, removed space-and-underscore-in-name code; see displaytype=help for more information
      # found (or didn't find), so cache title and possibly forward
      # note: $N may be invalid, but we're still caching the miss-hit, so we don't try getting it again

      $cachedIDs->{$N->{node_id}} = $N if defined $N;
      $cachedTitles->{$ident} = $N;
      $cachedTitles->{$forwarded} = $N;
    }

    return $N;
  };

  # returns a list ref of items in a given parameter
  # if a given parameter (in $param) is invalid, an empty list ref is returned
  # otherwise, a list ref of all items is returned

  local *getParamList = sub {
    my $p=$_[0];
    my @l = ();
    if( (defined $p) && (exists $params->{$p}) && (defined $params->{$p}) )
    {
      $p=$params->{$p};
      my $r=ref $p;
      if($r eq '')
      {
        @l = ($p);
      } elsif($r eq 'SCALAR') {
        @l = ($$p);
      } elsif($r eq 'ARRAY') {
        return $p;
      } elsif($r eq 'HASH') {
        @l = keys(%$p);
      }
    }
    return \@l;
  };


  #
  # main function
  #

  # determine author
  # note: in most cases, we'll just skip to the last 'unless' to use current user

  my $aid = $params->{author_id};
  if((defined $aid) && length($aid) && $aid && ($aid =~ /^(\d+)$/))
  {
    $aid = getNodeById($1,'light') || undef;	#note that this allows any node to /msg user
    $aid = (defined $aid) ? $aid->{node_id} : undef;
  } else {
    undef $aid;
  }

  unless(defined $aid)
  {
    #don't know author ID, so try to get author name
    $aid = $params->{author};
    if((defined $aid) && length($aid))
    {
      $aid = getCached($aid) || undef;
      $aid = (defined $aid) ? $aid->{node_id} : undef;
    }
  }

  unless(defined $aid)
  {
    #don't know author's title, either, so just use current user
    $aid = $UID;
  }


  # determine node message is about
  # note: if message table is expanded to include something like 'about_node', this section can be mostly removed

  my $aboutNode = $params->{renode_id};
  if((defined $aboutNode) && length($aboutNode) && $aboutNode && ($aboutNode=~/^(\d+)$/))
  {
    $aboutNode = getNodeById($1,'light') || undef;
    if(defined $aboutNode)
    {
      $aboutNode = length($aboutNode->{title}) ? $aboutNode->{title} : 'id://'.$aboutNode->{node_id};
    }
  } else {
    undef $aboutNode;
  }

  unless(defined $aboutNode)
  {
    $aboutNode=$params->{renode};
    if((defined $aboutNode) && length($aboutNode) && ($aboutNode=~/^(.+)$/))
    {
      $aboutNode=length($1) ? $1 : undef;
    } else {
      undef $aboutNode;
    }
  }

  # determine time to say message was sent
  my $sendTime = $params->{renode_id};
  if((defined $sendTime) && ($sendTime =~ /^(\d{14,})$/))
  {
    #Y10K compliant
    $sendTime = $1;
  } else {
    undef $sendTime;
  }

  # determine which usergroup to say message was from
  my $fromGroup = $params->{fromgroup_id};
  if( (defined $fromGroup) && length($fromGroup) && $fromGroup && ($fromGroup=~/^(\d+)$/) )
  {
    $fromGroup = getNodeById($1,'light') || undef;
    if(defined $fromGroup)
    {
      $fromGroup = $fromGroup->{node_id};
    }
  } else {
    $fromGroup = 0;
  }

  unless($fromGroup)
  {
    if((defined $fromGroup) && length($fromGroup) && ($fromGroup=~/^(.+)$/))
    {
      if(length($1))
      {
        $fromGroup=getCached($1);
        $fromGroup = (defined $fromGroup) ? $fromGroup->{node_id} : 0;
      } else {
        $fromGroup=0;
      }
    } else {
      $fromGroup=0;
    }
  }

  #
  # determine recipient(s)
  #

  # determine who is online

  my %onlines = ();
  my $onlineOnly = boolParam('ono');

  if($onlineOnly)
  {
    # ripped from message (opcode)
    my $csr = $DB->sqlSelectMany('member_user', 'room', '', '');
    while(my ($ol) = $csr->fetchrow)
    {
      $onlines{$ol}=1;
    }
    $csr->finish;
  }

  #determine which groups get a copy sent to themselves
  my $ccGroups = boolParam('ccgroup');

  my $countUserAll = 0;	#count of users we tried to /msg, including those ignoring us
  my $countUserGot = 0;	#count of users that got our message
  my $countGroupGot = 0;	#count of groups that got our message
  
  # users who blocked us; key is user ID, value is 0 if blocked, 1 if possibly blocked (happens ignoring the usergroup, but could still get msg via another usergroup)
  #  after trying to send to everybody, anything with value of 1 is added to $countUserAll
  my %blockers = ();

  my %groups = ();	#groups that get a message; key is group ID, value is -1 if user isn't allowed to send there, 0 if usergroup doesn't get message (but people in it do), higher than 0 means the usergroup also gets the message
  my %users = ();	#users that get a message; key is user ID, value is group they're in (or 0 for none) (or -1 to not send to them)

  # %users is a hash so if multiple usergroups are messaged, the user will get a group message for a group they're in, instead of potentially a group they aren't in


  # returns a value in $VARS->{_argument_}, constrained to the given values
  # parameters are all required:
  #	value to get value of in VARS
  #	default value to return, if value is not in VARS hash, or value is not one of the given values
  #	list or list ref of valid values
  # returns if all arguments aren't supplied
  # created: 2002.06.15.n6
  # updated: 2002.06.15.n6

  # TODO move into npbutil, after it is cleaned a bit
  # TODO bool version also for npbutil

  local *getVarsValue = sub {
    my ($varsKey, $defaultVal, @allowedValues) = @_;
    return unless (defined $varsKey) && length($varsKey);

    # possibly change list ref into list
    if( (scalar(@allowedValues)==1) && ((ref $allowedValues[0]) eq 'ARRAY') )
    {
      @allowedValues = @{$allowedValues[0]};
    }

    # determine what to return
    return $defaultVal unless exists $VARS->{$varsKey};
    my $val = $VARS->{$varsKey};
    foreach(@allowedValues)
    {
      return $val if $_ eq $val;
    }

    return $defaultVal;

  };


  #
  # flag recipients
  #


  # adds a user to the list to get the message (or not get message)
  # pass user object and optionally group ID (if no group is passed, defaults to no group)
  # included in things this functions does:
  #  all checks for where a user would not get a message: online-only, ignoring user, ignoring group
  #  finding (and possibly increasing) the msg group level
  # updated: 2002.11.09.n6

  local *addUser = sub {
    my ($userObj, $groupID) = @_[0,1];
    return unless defined $userObj;
    $groupID = (defined $groupID) ? $groupID : 0;
    my $uid = $userObj->{node_id};

    if(exists $users{$uid})
    {
      # user is already getting message
      return if $users{$uid}==-1;	#user doesn't want message

      # if this is a group message, see if user knows it is from a group
      if($groupID && ($users{$uid}==0))
      {
        # user doesn't know this is from a group, so say it is
        $users{$uid}=$groupID;
      }
      # note: should always be true, but just in case
    } else {
      #user isn't set to get/not get a message

      # check for ignoring author
      if( $APP->userIgnoresMessagesFrom($uid, $aid) )
      {
        $users{$uid}=-1;
        $blockers{$uid}=0;
        ++$countUserAll;
        return;
      }

      # check for online only
      # this check should be before ignore-usergroup test; otherwise, the blocked-user message incorrectly includes people who are just ignoring OnO messages
      if($onlineOnly && !exists $onlines{$uid})
      {
        # message is online-only and the recipient isn't online
        # see if they want the message anyway
        # TODO? cache this?

        my $v = getVars($userObj);
        unless( $v->{getofflinemsgs} )
        {
          # user doesn't want ONO messages, and this msg was ONO, so block them from getting the message (to prevent having to look up their VARS again)
          $users{$uid}=-1;
          return;
        }
      }

      # check for ignoring usergroup
      #  The proper thing to do isn't clear when the recipient user is in
      #  several of the usergroups this message is going to, and the
      #  recipient is ignoring some groups, but not others. We could either
      #  block the message if ANY of the usergroups are ignored, or block if
      #  ALL of the usergroups are ignored. The latter case is done here;
      #  this means there is a lower chance you'll miss a message you meant
      #  to get, although there is a higher chance you'll get a message you
      #  did not want.

      if($groupID)
      {
        $blockers{$uid}=$groupID;	#non-zero means may still get message
        # don't mark as send-message, but also don't mark as do-not-send-at-all
        return if( $APP->userIgnoresMessagesFrom($uid, $groupID) );
        # note: countUsersAll is not adjusted here, so it doesn't count the same recipient twice; it is added later ("deal with people who blocked")
      }

      # passed all checks, so allow message to be sent to user
      delete $blockers{$uid};	#if blocked from 1 usergroup, but got anyway, forget that we tried to block
      ++$countUserAll;
      ++$countUserGot;
      $users{$uid}=$groupID;
    }
  };

  # adds a user or usergroup to get a message (or not get the message)
  # pass user or usergroup object
  # updated: 2004.12.12.n0 (Sunday, December 12, 2004)

  local *addRecipient = sub {
    my $u = $_[0];
    return unless defined $u;
    my $i=$u->{node_id};

    if( $APP->isUsergroup($u) )
    {
      if(exists $groups{$i})
      {
        # already did this group, don't bother with again
        next;
      }
         
      unless($APP->inUsergroup($USER, $u) )
      { 
        push @problems, 'You are not allowed to message the ['.$u->{title}.'] usergroup.';
        $groups{$i}=-1;
        return;
      }

      # all checks pass, so send /msg to group and members
      ++$countGroupGot;

      # see if usergroup itself gets a copy
      if($ccGroups)
      {
        # htmlcode caller forced groups to get
        $groups{$i} = $i;
      } else {
        $groups{$i} = ($APP->getParameter($i, 'allow_message_archive') ) ? $i : 0;	#see if group gets a copy
      }

      # loop though all users
      foreach( @{$DB->selectNodegroupFlat($u)} )
      {
        addUser($_, $i);
      }

    } else {
      addUser($u);

    }
  };

  # invalid node titles, aliases, and node IDs
  #  key is invalid item
  #  value is always 1

  my %invalidIDs = ();
  my %invalidNames = ();

  # for each recipient, either:
  #  add to send list
  #  reject for some reason (examples: permission denied, online-only)
  #  add to invalid item list

  # this is the only place where recipients are added to the list to be messaged
  my $n = undef;
  foreach( @{getParamList('recipient_id')} )
  {
    $n = getCached($_,1);
    if(defined $n)
    {
      addRecipient($n);
    } else {
      $invalidIDs{$_}=1;
    }
  }

  foreach( @{getParamList('recipient')} )
  {
    $n = getCached($_);
    if(defined $n)
    {
      addRecipient($n);
    } else {
      $n = $_;
      $n =~ tr/ /_/;
      $invalidNames{$n}=1;
    }
  }

  # deal with people who blocked
  my @whoBlocked = ();	#users who blocked sender, and not because blocking the group (listing all the group blockers could get large fast)
  my $numBlocked = scalar(keys(%blockers));
  my $numBlockedGroup = 0;	#number of messages blocked because blocking usergroup
  foreach(keys(%blockers))
  {
    if($blockers{$_}==0)
    {
      # blocking sender
      push(@whoBlocked, getCached($_,1));
    } else {
      # blocking usergroup(s)
      ++$countUserAll; #not done in addUser, so do it now
      ++$numBlockedGroup;
    }
  }
  my $blockedInfoMethod = getVarsValue('informmsgignore', 0, 0,1,2,3);	#0=inform via msg, 1=inform in 'you said "blah"' area in chatterbox, 2=inform both ways, 3=don't inform

  if($numBlocked && ($blockedInfoMethod==0 || $blockedInfoMethod==2))
  {
    # inform via a msg
    my $bMessage = 'You were blocked by '.$numBlocked.' user'.($numBlocked==1?'':'s').' total';
    my @bReason = ();
    push(@bReason, $numBlockedGroup.' ignored the usergroup(s)') if $numBlockedGroup;
    push(@bReason, scalar(@whoBlocked).' ('.join(', ', map { '[' . $_->{title} . ']' } @whoBlocked).') ignored you') if scalar(@whoBlocked);
    $bMessage .= ': '.join(', ', @bReason) if scalar(@bReason);	#note: should always be true, but just in case
    $bMessage .= '.';
    push(@problems, $bMessage);
  }

  # when sending a message and we aren't a recipient, but we get it anyway, pick one of the normal recipients to be the for_usergroup
  #  if the message was sent to any usergroups, pick one of those
  #  otherwise, pick a random user
  #  in either case, this will return the node_id of the choosen node for for_usergroup
  # created: 2002.07.28.n0
  # updated: 2002.12.02.n1

  local *pickRandomForGroup = sub {
    #first try a random group
    foreach(keys(%groups))
    {
      if($_ >= 0) { return $_; }	#if -1, then that group didn't get the message
    }

    #not sending to any groups, so pick a random user besides the sending user
    foreach(keys(%users))
    {
      return $_ unless $_==$UID;	#yourself as a group is rather annoying
    }

    return 0; # note: should always be true, but just in case
  };


  # special case sender getting msg
  if(boolParam('ccself'))
  {
    # set the for-group as just a random recipient of the message
    # this is far from perfect, but there isn't a way to store all recipients, so this will have to do
    # done here, and not relied upon at the actual msg-send part so we try to not get ourselves as the for-group we're sending to

    # if sending to at least 1 group, try to make that the from group

    # since we aren't sending to any groups, pick a random person
    unless(exists $users{$UID})
    {
      $users{$UID} = pickRandomForGroup() || $UID;	#extra OR is for very rare case so user still gets CC-to-self message when nobody gets message (such as everybody is blocking sender)
    }
  }

  # add things to message
  if($onlineOnly)
  {
    # say ONO even for CCed to self message as a reminder of how it was sent
    $msg = 'OnO: ' . $msg;
  }

  if(defined $aboutNode)
  {
    # maybe FIXME: add another field to message table, although this wouldn't be used much (just for WU title area)
    $msg = 're ['.$aboutNode.']: '.$msg;
  }

  # construct invalid recipients message
  my $s = '';
  my @badIDs = sort { ($a<=>$b) || ($a cmp $b) } keys(%invalidIDs);
  if($n=scalar(@badIDs))
  {
    $s = 'Node ID' . ($n==1
      ? ' ' . $badIDs[0] . ' is not a valid user or usergroup ID.'
      : 's ' . join(', ', @badIDs) . ' are not valid user or usergroup IDs.');
  }

  my @badNames = sort { $a cmp $b } keys(%invalidNames);
  if($n=scalar(@badNames))
  {
    $s .= ' ' if length($s);
    if($n==1)
    {
      $s .= $APP->encodeHTML($badNames[0]) . ' is not a valid user or usergroup name or alias.';
    } else {
      $s .= $APP->encodeHTML(join(@badNames)) . ' are not valid user or usergroup names or aliases.';
    }
  }

  if(length($s))
  {
    push(@problems, $s . ' You tried to say: \\n ' . $APP->encodeHTML($msg));	#slash, then 'n', not newline
  }


  #
  # finally send the message
  #

  my @getters = ();	#groups and users that got message

  # send to groups archive
  foreach my $i (keys(%groups))
  {
    next if $groups{$i}<0;	#negative indicates user isn't allowed to send to group

    push(@getters, $i);	#count as 1 for group
    next if $groups{$i}==0;

    $DB->sqlInsert('message',{'msgtext' => $msg,'author_user' => $aid,(defined($sendTime)?('tstamp' => $sendTime):()),
      'for_user' => $i,
      'for_usergroup' => $i,	#don't bother with ($i || $fromGroup) since $i is never going to be 0
    });
  }

  # send to users
  my $forUG = undef;
  my $isArchived = undef;
  foreach my $i (keys(%users))
  {
    next if $users{$i}<0;
    $forUG=$users{$i};
    if($i==$UID)
    {
      # the for-group is really just a random recipient of the message
      # this is far from perfect, but there isn't a way to store all recipients, so this will have to do
      # if the msg was forced-gotten, then this was already done; but this is for the normal case

      $forUG ||= pickRandomForGroup();
    }
    $isArchived=0;
    $forUG ||= $fromGroup;

    push(@getters, $i) if $users{$i}==0; # only list people that aren't in a UG (otherwise, UG recipient list would be quite large)

    $DB->sqlInsert('message',{
      'msgtext' => $msg,
      'author_user' => $aid,
      (defined($sendTime)?('tstamp' => $sendTime):()),
      'for_usergroup' => ((defined $forUG)?($forUG):(0)),
      'for_user' => $i,
      'archive' => $isArchived,
    });

    # message_id is auto
    # room is 0
  }

  # inform user of any problems
  #  since these are sent back to the sending user, increase the maximum message length

  if(scalar(@problems))
  {
    my $rootUser = getNode('root','user','light') || undef;
    $rootUser = (defined $rootUser) ? ($rootUser->{node_id} || 0) : 0;
    foreach my $prob (@problems)
    {
      $DB->sqlInsert('message',{
        'msgtext' => $prob,
        'author_user' => $rootUser,
        'for_user' => $UID,	#the actual user gets the error(s), not the author we say is sending the message
      });
    }
  }

  # link to groups and users that were messaged
  # parameters: node_id of user, optional alternate text to display

  local *linkU = sub {
    my $id = $_[0];
    my $altDisp = $_[1] || undef;
    return '<em title="sendPrivateMessage (htmlcode)">!!! nobody !!!</em>' unless $id;
    return linkNode($id, ((defined $altDisp) ? $altDisp : getCached($id,1)->{title}));
  };


  #
  # sent /msg information
  #

  # if multiple messages sent at same time (such as through the WU header area), find the query param to use
  my $qpm = 'sentmessage';
  if( defined $query->param($qpm) )
  {
    my $i=0;
    while(defined $query->param($qpm.$i) )
    {
      ++$i;
    }
    $qpm=$qpm.$i;
  }

  # UIDs for Virgil, CME, Klaproth, and root.
  my @botlist = qw(1080927 839239 952215 113);
  my %bots = map{$_ => 1} @botlist;

  # escape for sender's display
  # Bots, don't escape HTML for them.
  unless( exists $bots{$aid} )
  {
    $msg = $APP->escapeAngleBrackets($msg);
    $msg = parseLinks($msg,0,1);
  }

  my $m = undef;
  if ( $aid==$UID)
  {
    $m = 'you said "' . $msg . '"';
    unless(scalar(@getters))
    {
      $m .= ' to nobody';
    } else {
      # TODO allow only certain recipients to not be shown

      # TODO loop though list anonrecipient, create hash, foreach loop
      #  checks hash to see if that recipient is anonymous

      # TODO recode entire engine
      my $anonRecipient = boolParam('anonrecipient');
      foreach (@getters)
      {
        $_ = ($anonRecipient) ? linkU($_,'?') : linkU($_);
      }
      $m .= ' to ' . join(', ', @getters);
    }
    $m .= ' (sent ';
    $m .= ' to '.$countUserGot.' noder'.($countUserGot==1?'':'s');
    $m .= ' and '.$countGroupGot
      .' group'.($countGroupGot==1?'':'s') unless $countGroupGot==0;

    if ($numBlocked)
    {
      # note: should always be true, but just in case
      $m .= ' (You were blocked by '.$numBlocked.' user'.($numBlocked==1?'':'s').' total';

      if ( $blockedInfoMethod==1 || $blockedInfoMethod==2 )
      {
        # inform who blocked
        my @bReason = ();

        push(@bReason, $numBlockedGroup.' ignored the usergroup(s)') if $numBlockedGroup;

        if (scalar(@whoBlocked) )
        {
          push(@bReason, scalar(@whoBlocked).' ('.join(', ', 
            map { linkU($_->{node_id}, $_->{title}) } @whoBlocked)
            .') ignored you') ;
        }

        # note: should always be true, but we haven't actually thought it through
        $m .= ': '.join(', ', @bReason) if scalar(@bReason);
      }

      $m .= '.)';
    }
  
    $m .= ')';                    # Dear sweet christ

    # Save a copy of the sent message notice into the sender's outbox (message_outbox table)
    #
    #   It would be useful to have this entry link back to the matching message in the "inbox"
    #   message table. However, what constitutes the matching message is ambiguous in scenarios
    #   where the message is delivered to multiple recipients (such as sent to a group, multiple
    #   users, etc) since an "inbox" table record is created for (and owned by) each recipient
    #   and none are distinctly a master. So for now no link is created.
    #
    $DB->sqlInsert('message_outbox',{
       'msgtext'     => $m,
       'author_user' => $aid,
       (defined($sendTime)?('tstamp' => $sendTime):()),
    });

  } else {
    $m = "You triggered a message from "
      .linkNode($aid)
      ." that reads \"$msg\"";
  }

  $query->param($qpm,$m);	#inform in chatterbox
  return $showWhatSaid ? $m : undef;
}

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
  return htmlcode( 'show content' , $input , "xml <entry> atominfo, $length" , ( atominfo => $atominfo) ) ;
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

sub verifyRequest
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  # checks that the form was a real e2 one
  my ($prefix) = @_;

  my $seed = scalar($query->param($prefix . '_seed'));
  $seed = '' if not defined($seed);
  my $email = $$USER{email} // '';
  my $test = md5_hex($$USER{passwd} . ' ' . $email . $seed);
  my $nonce = scalar($query->param($prefix . '_nonce'));
  return (defined($nonce) and $test eq $nonce) ? 1 : 0;
}

# isInfected REMOVED - Dead code, old infection game feature. Jan 2026.

# ip_lookup_tools REMOVED - Migrated to React UserToolsModal. Jan 2026.

sub blacklistIP
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

#	purpose
#		add an IP address to the blacklist table or update an existing
#		entry for the address
#
#	parameters
#		IP to block, reason to block it
#
#	returns
#		error report or report on action done
#
	my ($ipToAdd, $blockReason) = @_;

	return 'No IP given to blacklist' unless $ipToAdd;
	# still waiting for IPv6...
	return "'".$APP->encodeHTML($ipToAdd)."' is not a valid IP address" unless $ipToAdd =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	my $result = '';

	my $data = {ipblacklist_user => $$USER{user_id}
		, ipblacklist_ipaddress => $ipToAdd
	};

	my $update = 0;

	my $listRef = $DB -> sqlSelect('ipblacklistref_id'
		, 'ipblacklist'
		, "ipblacklist_ipaddress = '$ipToAdd'"
	);

	if ($listRef){
		$$data{ipblacklistref_id} = $listRef;
		$update = {%$data
			, -ipblacklist_comment => 'CONCAT('.$DB->quote("$blockReason <br>&#91;").
				", ipblacklist_timestamp, ']: ', ipblacklist_comment)"
		};
		$result = "updated IP blacklist entry for $ipToAdd";
	}else{
		$DB -> sqlInsert('ipblacklistref', {});
		$$data{-ipblacklistref_id} = 'LAST_INSERT_ID()';
		$$data{ipblacklist_comment} = $blockReason;
		$result = "added $ipToAdd to IP blacklist";
	}

	return "Error adding $ipToAdd to blacklist" unless
		$DB -> sqlInsert('ipblacklist', $data, $update);

	$APP->securityLog(SECLOG_IP_BLACKLIST, $USER, "$$USER{title} $result: \"$blockReason.\"");
	$result =~ s/^(\w)/\u$1/;
	return $result;
}

sub lock_user_account
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $APP = shift;

  my ($uid) = @_;
  getRef $uid;
  return unless $uid;
  return unless($$uid{type_nodetype} == getId(getType('user')));
  $$uid{acctlock} = $$USER{user_id};

  $APP->securityLog(SECLOG_ACCOUNT_LOCK, $USER, "$$uid{title}'s account was locked by $$USER{title}");

  # Delete all public messages from locked user
  $DB->sqlDelete('message', "for_user = 0 AND author_user = $$uid{user_id}");

  # revert all review drafts to 'findable' status
  # (they won't actually be findable unless/until the account is unlocked)
  $DB -> sqlUpdate('draft JOIN node ON draft_id=node_id', {publication_status => getId(getNode('findable', 'publication_status'))}, "node.author_user = $$uid{node_id} AND
    draft.publication_status = " . getId(getNode('review', 'publication_status')));

  return updateNode($uid, -1);
}

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
