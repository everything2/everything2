package Everything::HTML;
#
#	Copyright 1999,2000 Everything Development Company
#
#		A module for the HTML stuff in Everything.  This
#		takes care of CGI, cookies, and the basic HTML
#		front end.
#
#############################################################################

use strict;
use Everything;

use Everything::Request;

use Encode;
use Everything::Response;
use Carp qw(longmess);

## no critic (ProhibitAutomaticExportation,RequireUseWarnings)

sub BEGIN {
	use Exporter ();
	use vars qw($DB $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
              %HEADER_PARAMS
              $DB
              $NODE
              $VARS
              $query
              parseLinks
              urlGen
              linkNode
              linkNodeTitle
              nodeName
              displayPage
              gotoNode
              encodeHTML
              processVarsSet
              mod_perlInit
              );
}

use vars qw($HTTP_ERROR_CODE $ERROR_HTML $SITE_UNAVAILABLE $query);
use vars qw($VARS);
use vars qw($GNODE);
use vars qw($USER);
use vars qw($REQUEST);
use vars qw(%HEADER_PARAMS);

my $HTTP_ERROR_CODE = 400;
my $SITE_UNAVAILABLE = <<ENDPAGE;
<html>
<head><title>Site Temporarily Unavailable</title>
</head>
<body>
<h1>Hamster Ball Jam in Cubicle Z</h1>
<p>
There is a temporary problem with Everything2.  Please hold while we contact the rodent experts.
</p>
</body>
</html>
ENDPAGE

    my $ERROR_HTML = <<ENDPAGE;
<html>
<head><title>Site Temporarily Unavailable</title>
</head>
<body>
<h1>Hamster Twinkie Overdose</h1>
<p>
The server hamsters have lost it.  They sent out a list of demands,
but nobody could understand their note.  It read:
</p>
<pre>
ERROR
</pre>
<p>
We're getting the best in rodent nutrition and negotiation on it.
</p>
</body>
</html>
ENDPAGE

my %NO_SIDE_EFFECT_PARAMS = (
	'node' => 1
	, 'author' => 1
	, 'a' => 1
	, 'node_id' => 1
	, 'type' => 1
	, 'guest' => 1
	, 'lastnode_id' => 'delete'
	, 'searchy' => 1
	, 'originalTitle' => 1
	, 'should_redirect' => 'delete'
);

sub handle_errors {

    # Re-throw if we're inside an eval so the eval can catch it (was
    # CGI::Carp::ineval(); $^S is Perl's own "currently in an eval" flag).
    CORE::die(@_) if $^S;

    Everything::printLog('Trying to handle error.');

    my $errorFromPerl = shift;
    $errorFromPerl .=
      "Call stack:\n"
      . (join "\n" => reverse $APP->getCallStack())
      ;
    Everything::printLog($errorFromPerl);
    Everything::printLog(query_vars_string());
    if (defined $query) {

        $errorFromPerl = $APP->encodeHTML($errorFromPerl);
        my $errorHeader = <<ENDHEADER;
Status: $HTTP_ERROR_CODE Internal Hamster Error
Content-type: text/html

ENDHEADER
        my $errorText = $ERROR_HTML;
        $errorText =~ s/\bERROR\b/$errorFromPerl/;
        $query->print($errorHeader . $errorText);
	exit;

    } else {

        print $errorFromPerl;

    }
    return;
}

sub query_vars_string {
	my $error = '';

	if (defined $query && defined $query->Vars()) {
		my $params = $query->Vars();
		for (keys %$params) {
			$error .= "\t- param: " . $_ . " = " . ($query->param($_) // '') . "\n";
		}
	}

	return $error;
}


sub encodeHTML
{
  return $APP->encodeHTML(@_);
}

#############################################################################
# htmlFormatErr / htmlErrorUsers / htmlErrorGods REMOVED (#4259) -- legacy
# server-rendered error-page formatters. After the htmlcode() dispatch was
# removed, the only caller (NodeBase getNodeCursor's stupid-query guard) threw
# the formatted output away; React / the router render everything now, so these
# never reached a browser. The guard now just printLog()s the bad query.
#############################################################################

sub urlGen
{
  return $APP->urlGen(@_);
}


sub linkNode
{
  return $APP->linkNode(@_);
}

sub linkNodeTitle
{
  return $APP->linkNodeTitle(@_);
}



#############################################################################
#	Sub
#		nodeName
#
#	Purpose
#		This looks for a node by the given name.  If it finds something,
#		it displays the node.
#
#	Parameters
#		$node - the string name of the node we are looking for.
#		$user_id - the user trying to view this node (for authorization)
#
#	Returns
#		nothing
#
sub nodeName
{
	my ($node, $user_id) = @_;

	my $matchall = $query->param("match_all");
	my $soundex = $query->param("soundex");

	my @types = $query->multi_param("type");
	foreach(@types) {
		$_ = getId($DB->getType($_));
	}

	my ($select_group, $search_group, $NODE);
	unless ($soundex or $query->param("match_all")) 
		# exact match only if these options are off
	{
		my %selecthash = (title => $node);
		my @selecttypes = @types;
		$selecthash{type_nodetype} = \@selecttypes if @selecttypes;
		$select_group = $DB->selectNodeWhere(\%selecthash);
	}

	my $type = $types[0];
	$type = "" unless $type;

	if (not $select_group or @$select_group == 0)
	{ 
		# We did not find an exact match, so do a search thats a little
		# more fuzzy.
		$search_group =
        	        $APP->searchNodeName($node, \@types, $soundex, 1);

		if($search_group && @$search_group > 0)
		{
			$NODE = getNodeById($Everything::CONF->search_results);
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = getNodeById($Everything::CONF->not_found_node);
		}

		return displayPage($NODE, $user_id);
	}
	elsif (@$select_group == 1)
	{
		# We found one exact match, goto it.
		my $node_id = $$select_group[0];
		gotoNode ($node_id, $user_id);
		return;
	}
	else
	{
		my @canread;
		my ($e2node, $node_forward, $draftCount) = (undef, undef, 0);
		foreach (@{ $select_group}) {
			getRef($_);
			my $node_type = $$_{type}{title} // '';
			# Drafts have special permission handling - use canSeeDraft instead of canReadNode
			if ($node_type eq 'draft') {
				next unless $APP->canSeeDraft($USER, $_, 'find');
				$draftCount++;
			} else {
				next unless canReadNode($USER, $_);
			}
			$e2node = $_ if $node_type eq 'e2node';
			$node_forward = $_ if $node_type eq 'node_forward';
			push @canread, $_;
		}

		return gotoNode($Everything::CONF->not_found_node, $user_id, 1) unless @canread;
		return gotoNode($canread[0], $user_id, 1) if @canread == 1;

		# Allow a node_forward to bypass an e2node if we're clicking through from
		#  one node to another
		return gotoNode($node_forward, $user_id, 1)
			if $node_forward && $e2node && defined $query->param('lastnode_id');

		return gotoNode($e2node, $user_id, 1) if $e2node;
		return gotoNode($node_forward, $user_id, 1) if $node_forward;

		if (scalar @canread - $draftCount == 1) {
			for my $notDraft (@canread) {
				return gotoNode($notDraft, $user_id, 1)
					if $$notDraft{type}{title} ne 'draft';
			}
		}

		#we found multiple nodes with that name.  ick
		$NODE = getNodeById( $Everything::CONF->default_duplicates_node );

		# Extract node_ids from the hashrefs for the group
		my @node_ids = map { $$_{node_id} } @canread;
		$$NODE{group} = \@node_ids;
		return displayPage($NODE, $user_id);
	}
}


#########################################################################
# sub htmlcode REMOVED (#4259) -- the htmlcode() dispatch is retired. It looked up
# Everything::Delegation::htmlcode subs by name (for embedded-perl / node use);
# every htmlcode has since migrated to Everything::Application (or a Controller/
# API), so there were no callers left. The htmlcode NODETYPE + table stay (the
# maintenance type stores its code in the htmlcode table; jsonexport extends
# htmlcode). The empty Delegation::htmlcode module + the htmlcode display
# controller are retained for now and retired alongside the maintenance work.
#########################################################################

#############################################################################
#	Sub
#		displayPage
#
#	Purpose
#		This is the meat of displaying a node to the user.  This gets
#		the display page for the node, inserts it into the appropriate
#		container, prints the HTML header and then prints the page to
#		the users browser.
#
#	Parameters
#		$NODE - the node to display
#		$user_id - the user that is trying to 
sub displayPage
{
	my ($NODE, $user_id) = @_;
	getRef $NODE, $USER;
	die "NO NODE!" unless $NODE;
	$GNODE = $NODE;

	# Fast-path for HEAD requests: return appropriate status without full rendering
	# This saves significant DB/CPU load from bots checking link existence
	if ($ENV{REQUEST_METHOD} eq 'HEAD') {
		my $status = 200;
		my $status_text = 'OK';

		if ($NODE->{node_id} == $Everything::CONF->not_found_node) {
			$status = 404;
			$status_text = 'Not Found';
		} elsif ($NODE->{node_id} == $Everything::CONF->permission_denied) {
			$status = 403;
			$status_text = 'Forbidden';
		}

		print "Status: $status $status_text\n";
		print "Content-Type: text/html; charset=utf-8\n";
		print "X-E2-Head-Optimized: 1\n\n";
		return;
	}

	my $isGuest = 0;
	my $page = "";
	$isGuest = 1 if $APP->isGuest($user_id);

	my $lastnode;
	if ($$NODE{type}{title} eq 'e2node') {
		$lastnode = getId($NODE);
	}elsif ($$NODE{type}{title} eq 'writeup') {
		$lastnode = $$NODE{parent_e2node};
	} elsif ($$NODE{type}{title} eq 'stylesheet') {
		$lastnode = -1;
	}


	my $type = $NODE->{type}->{title};

	my $displaytype = $query->param('displaytype');

	# All routing is handled by HTMLRouter - it always succeeds
	# (unimplemented pages get a friendly error via React)
	$page = '';
	$Everything::ROUTER->route_node($NODE, $displaytype || 'display', $REQUEST);
	setVars($USER, $VARS) unless $APP->isGuest($USER);

	return;
}


#############################################################################
#the function where we go when we actually know which $NODE we want to view
sub gotoNode
{
	my ($node_id, $user_id, $no_update) = @_;

        #jb: no_update will short out the canUpdateNode stuff
        #it's a little hacky, but basically it will keep people
        #from editing nodes by name and shave off a pile of 
        #cycles. Editing by name is unnecessary

	my $NODE = {};
	unless (ref ($node_id) eq 'ARRAY') {
		# Is there a reason why we are "force"ing this node?
		# A 'force' causes us not to use the cache.
		$NODE = getNodeById($node_id, 'force');
	}
	else {
		$NODE = getNodeById($Everything::CONF->search_results);
		$$NODE{group} = $node_id;
	}

	unless ($NODE) { $NODE = getNodeById($Everything::CONF->not_found_node); }
	
	unless (canReadNode($user_id, $NODE)) {
		$NODE = getNodeById($Everything::CONF->permission_denied);
	}

        if($NODE->{type}->{title} eq "draft" && !$APP->canSeeDraft($user_id, $NODE))
        {
                # if you can't see a draft, you don't need/want to know it's there
                $NODE = getNodeById($Everything::CONF->not_found_node);
        }

	# Fast-path for HEAD requests: return appropriate status without full rendering
	# This saves significant DB/CPU load from bots checking link existence
	if ($ENV{REQUEST_METHOD} eq 'HEAD') {
		my $status = 200;
		my $status_text = 'OK';

		if ($NODE->{node_id} == $Everything::CONF->not_found_node) {
			$status = 404;
			$status_text = 'Not Found';
		} elsif ($NODE->{node_id} == $Everything::CONF->permission_denied) {
			$status = 403;
			$status_text = 'Forbidden';
		}

		print "Status: $status $status_text\n";
		print "Content-Type: text/html; charset=utf-8\n";
		print "X-E2-Head-Optimized: 1\n\n";
		return;
	}

	#these are contingencies various things that could go wrong

	my $displaytype = $query->param("displaytype");

	# Legacy node-update-via-URL path REMOVED (#4198). gotoNode used to apply
	# edits inline when a request carried add / group / <type>_<field> params --
	# the form the `openform` htmlcode rendered, XSRF-guarded for verify_edits
	# types (nodetype/user/sustype) by verifyRequest. openform and that form are
	# gone; all editing now goes through APIs (basicedit, usergroups, nodegroups),
	# so this block was dead but still XSRF-reachable. verifyRequest /
	# verifyRequestHash are now caller-free and retired.
	

	#updateHits ($NODE, $USER) unless $query->param('op') ne "" or $query->param("displaytype") eq "ajaxupdate";

	# Create softlinks -- a linktype of 0 is the default
	my $linktype = 0;
	$linktype = getNodeById($Everything::CONF->guest_link)
		if $APP->isGuest($USER);

	# Get lastnode_id from query param first, then fall back to cookie
	# Cookie-based tracking enables softlink creation with clean SEO-friendly URLs
	my $lastnode = $query->param('lastnode_id');
	if (!$lastnode) {
		$lastnode = $query->cookie('lastnode_id');
	}
	my ($fromNodeLinked, $toNodeLinked) =
		updateLinks($NODE, $lastnode, $linktype, $$USER{user_id});

	my $shouldRedirect = $query->param("should_redirect");
	# Redirect to URL without lastnode_id if this is a GET request and we only
	#  have params that we know to have no side-effects
	$shouldRedirect = 1
		if defined $query->param('lastnode_id') && $query->request_method() eq 'GET'
			&& $$NODE{type}{title} eq 'e2node'
			;

	if ($shouldRedirect) {
		# Build a throwaway, mutable copy of the request params for the redirect
		# (the side-effect-param stripping below must not mutate the real $query,
		# which is reused if we end up NOT redirecting). GET-only path (the
		# $shouldRedirect guard), so a single value per param is sufficient for
		# the canonical URL. No CGI object -- a plain param hash + the CGI-free
		# Everything::Response for the 303 header.
		my %redir_params = map { $_ => scalar $query->param($_) } $query->param;
		my $safeToRedirect = 1;
		delete $redir_params{op} if defined $redir_params{op} && $redir_params{op} eq "";
		foreach my $p (keys %redir_params) {
			$safeToRedirect = 0 unless defined $NO_SIDE_EFFECT_PARAMS{$p};
			delete $redir_params{$p} if(defined($NO_SIDE_EFFECT_PARAMS{$p}) and $NO_SIDE_EFFECT_PARAMS{$p} eq 'delete');
		}

		if ($safeToRedirect) {
			my $noQuotes = 1;

			# Generate relative URL without hostname/port for proper development environment support
			my $url = urlGen(\%redir_params, $noQuotes, $NODE);

			# Emit the canonical 303 (Status/Location) for app.psgi's STDOUT
			# capture to turn into the redirect. Was a raw CGI ->redirect();
			# now Everything::Response (no CGI). This is the #4237 redirect site.
			my $redir_header = Everything::Response->cgi_redirect(
				-uri => $url
				, -status => 303
				, -Cache_Control => 'private, no-cache, no-store'
			);
			print $redir_header;
			return;
		}
	}

	# So we can cache even linked pages, remove lastnode_id
	# unless it's a superdoc (so Findings: still gets the param)
	if ($APP->isGuest($USER) && $$NODE{type}{title} ne 'superdoc') {
		$query->delete('lastnode_id');
	}

	# Check if we were just silently redirected from a softlink creation,
	#  and pass that node_id through
	if (!$fromNodeLinked) {
		my $dbh = $DB->getDatabaseHandle();

		# Atomically find and mark the oldest unshown softlink creation
		# This replaces the get_recent_softlink stored procedure
		$dbh->begin_work;
		my $txn_ok = eval {
			my $sth = $dbh->prepare("
				SELECT softlink_creation_id, from_node
				FROM softlink_creation
				WHERE creater_user_id = ?
					AND to_node = ?
					AND displayed = 0
				ORDER BY create_time ASC
				LIMIT 1
				FOR UPDATE
			");
			$sth->execute($$USER{node_id}, $$NODE{node_id});
			my ($scid, $from_node) = $sth->fetchrow_array();

			if ($scid) {
				$dbh->do("UPDATE softlink_creation SET displayed = 1 WHERE softlink_creation_id = ?",
					undef, $scid);
				$fromNodeLinked = $from_node;
			}

			$dbh->commit;
			1;
		};
		if (!$txn_ok) {
			my $rollback_ok = eval { $dbh->rollback; 1 };
		}
	}

	$query->param('softlinkedFrom', $fromNodeLinked);

	# make sure editing user is allowed to edit
	if ($displaytype and $displaytype eq "edit") {
		unless (canUpdateNode ($USER, $NODE)) {
			$NODE = getNodeById($Everything::CONF->permission_denied);
			$query->param('displaytype', 'display');
		}
	}

	return displayPage($NODE, $user_id);
}


sub parseLinks {
  return $APP->parseLinks(@_);
}


#############################################################################
# printHeader REMOVED (#4259) -- legacy mod_perl HTTP-header printing. Under
# PSGI, Plack / the response builder own response headers; nothing called this
# (only a stale comment referenced it).
#############################################################################


#############################################################################
#	Sub
#		handleUserRequest
#
#	Purpose
#		This check the CGI information to find out what the user is trying
#		to do and executes their request.
#
#	Parameters
#		None.  Uses the global package variables.
#
sub handleUserRequest{
  my $user_id = $$USER{node_id};
  my $node_id;
  my $nodename;
  my $author;
  my $code;
  my $handled = 0;
  my $noRemoveSpaces = 0;

  my $defaultNode = $Everything::CONF->default_node;

  if ( $APP->isGuest($USER) ){
    $defaultNode = $Everything::CONF->default_guest_node;
  }

  if ($query->param('node')) {
    # Searching for a node my string title
    my $type  = $query->param('type') // '';  # undef when no type= param; both
                                               # 'writeup' eq-checks below warned

    $nodename = $APP->cleanNodeName(scalar $query->param('node'), $noRemoveSpaces);

    $author = $query->param("author");
    $author = getNode($author,"user");

    if ($nodename eq "") {
      gotoNode($defaultNode, $user_id);
      return;
    }

    if ($author and $type eq 'writeup') {
      my $parent_e2node = getNode($nodename, 'e2node', 'light');
      $parent_e2node = getId($parent_e2node);

      # Prefer a writeup whose parent matches the title exactly, if any
      # if not, prefer a draft with exact title, if any
      # otherwise, a writeup starting with the given title
      my @choices = ();
      push @choices , ['writeup', { -parent_e2node => $parent_e2node}] if $parent_e2node;
      push @choices , ['draft', {title => $nodename}],
        ['writeup', {"-LIKE-title" => $DB->quote($nodename . '%')}];

      foreach (@choices){
          my ($writeup) =
            getNodeWhere(
              {
                "-author_user" => $$author{user_id},
                %{$_->[1]}
              }
              , $_->[0]
            );

          if ($writeup) {
            gotoNode($writeup, $user_id);
            return;
          }
      }

    }

    if ($query->param("author") && $type eq 'writeup') {
      # Since an author specific search didn't work, throw out the
      #  author and search for e2nodes instead
      $query->delete("author");
      $query->param("type", 'e2node');
      $query->param("should_redirect", 1);
    }
    $query->param("node", $nodename);

    if ($query->param('op') ne 'new') {
      nodeName($nodename, $user_id);
    }
    else {
      gotoNode($Everything::CONF->permission_denied, $user_id);
    }
  }
  elsif ($node_id = $query->param('node_id')) {
    #searching by ID
    gotoNode($node_id, $user_id);
  }
  else {
    #no node was specified -> default
    gotoNode($defaultNode, $user_id);
  }

  return;
}

############################################################################
sub clearGlobals
{
	$GNODE = "";
	$USER = "";
	$VARS = "";
	$query = "";
	$REQUEST = undef;

	return;
}


#############################################################################
# opNuke REMOVED - op=nuke retired; node deletion is now POST
# /api/collaborations/:id/action/delete (its only callers were the collaboration
# components). Reuses can_delete_node + $node->delete, same as Everything::API::nodes.
# Callers: Collaboration.js, CollaborationEdit.js. #4335 Phase 2. Jun 2026.


#############################################################################
# opLogin + execOpCode REMOVED - op=login was the last built-in op= handler.
# Account activation and password reset are now POST /api/users/confirm
# (Everything::API::users::confirm: validates the token, sets the password, logs
# in, and on activation sends the welcome PM). The main login form uses POST
# /api/sessions/create. With op=login gone there are no op= handlers left, so the
# execOpCode dispatch and its mod_perlInit call site were removed too. This
# completes the op= wind-down. #4335 Phase 3. Jun 2026.

#############################################################################
# opLogout REMOVED - op=logout retired; logout is now POST /api/sessions/delete
# (Everything::API::sessions::delete clears the cookie server-side). Callers:
# LogoutLink.js, MobileProfileMenu.js. #4335 Phase 2. Jun 2026.


#############################################################################
# opNew REMOVED - op=new retired; node creation is now POST /api/node/create
# (Everything::API::node: canCreateNode + insertNode, returns node_id). Callers:
# CreateNode, CreateCategory, E2CollaborationNodes, Findings, NothingFound,
# CreateARegistry, EverythingPublicationDirectory, EdevDocumentationIndex,
# ClientdevHome. #4340 / #4335 Phase 2. Jun 2026.


#############################################################################
#	Sub
#		mod_perlInit
#
#	Purpose
#		This is the "main" function of Everything.  This gets called for
#		each page load in an Everything system.
#
#	Parameters
#		$db - the string name of the database to get our information from.
#
#	Returns
#		nothing useful
#
sub mod_perlInit
{
	if($Everything::CONF->maintenance_message)
	{
		print "Content-Type: text/html\n\n";
		print $Everything::CONF->maintenance_message."\n";
		return;
	}

	#blow away the globals
	clearGlobals();

	Everything::initEverything();

	$REQUEST = Everything::Request->new;

	# Initialize our connection to the database

	if (!defined $DB->getDatabaseHandle()) {
		$query->print($SITE_UNAVAILABLE);
		return;
	}

	%HEADER_PARAMS = ( );

	## no critic (RequireLocalizedPunctuationVars)
	$SIG{__DIE__} = \&handle_errors;   # was CGI::Carp::set_die_handler

	$query = $REQUEST->cgi;

	# #4060: rebuild node/type/author params from REQUEST_URI when the
	# title-bearing rewrite rules in apache2.conf can't faithfully convey
	# them. Apache URL-decodes the path before mod_rewrite matches it, then
	# inserts the decoded $N directly into the new query string — so a title
	# containing '&' (e.g. "Sense & Sensibility", sent as %20%26%20 in the
	# URI) ends up as literal `?node=Sense & Sensibility` and CGI truncates
	# at the bare '&'. The [B] flag's defaults preserve '&' as a query
	# separator, [B=&] drops default space escaping, and chaining them double-
	# encodes. The clean fix is to re-derive the canonical title from the
	# unmodified REQUEST_URI here. Matches the existing route patterns; any
	# %XX escapes are decoded once (Apache leaves them alone in REQUEST_URI).
	_recover_route_params_from_request_uri($query);

	$USER = $REQUEST->user->NODEDATA;
    $VARS = $REQUEST->user->VARS;

         # op=randomnode REMOVED - now GET /api/randomnode + goToRandomNode()
         # (react/utils/randomNode.js). #4335 Phase 3.

	$APP->refreshVotesAndCools($USER, $VARS);

	# op= dispatch removed entirely (#4335 Phase 3) -- all actions are APIs now.

	# Do the work.
	handleUserRequest();

	$DB->closeTransaction();
	return;
}

#####################
# sub
#   _recover_route_params_from_request_uri
#
# purpose
#   Re-derive node/type/author CGI params from the raw REQUEST_URI when
#   the title-bearing apache2.conf rewrites have lost characters to query-
#   string parsing. Primary case (#4060): titles containing '&' end up as
#   `?node=Sense & Sensibility`, and CGI truncates at the literal '&' to
#   `node=Sense `. Apache leaves REQUEST_URI untouched (still %26-encoded),
#   so we re-extract from there and overwrite the params.
#
#   Patterns mirror the rewrites in etc/templates/apache2.conf.erb. Any
#   path component captured here is percent-decoded once before being
#   stuffed back into the CGI params (CGI->param values are already-decoded
#   strings).
sub _recover_route_params_from_request_uri
{
	my ($q) = @_;

	# An explicitly-submitted node/node_id (form POST or query param) is
	# authoritative -- do NOT let the URL-path recovery overwrite it. Pre-PSGI
	# these forms posted to /index.pl (a node-less path) so the path never
	# competed; now that app.psgi maps SCRIPT_NAME to the full request path, a
	# form posting back to its own node-bearing URL (e.g. Master Control's node
	# search) would otherwise have its node clobbered by the path. Yielding to the
	# explicit param fixes that whole class in one place. Normal navigation (a
	# plain GET with no node param) is unaffected: recovery still runs and sets it.
	return if defined $q->param('node') || defined $q->param('node_id');

	my $uri = $ENV{REQUEST_URI};
	return unless defined $uri && length $uri;

	# Drop query string and any fragment — we only care about the path.
	$uri =~ s/[?#].*$//;

	# Legacy E2 URLs use '+' to mean space in the path (e.g. the
	# hard-coded /title/Message+Inbox link in Messages.js). Strict RFC 3986
	# would say '+' is only a space in query strings, not paths — but the
	# rest of the stack (Apache rewrite + CGI form decoding) has always
	# honored '+'-as-space here, so this helper has to match or it
	# overwrites CGI's correct decode with a broken one (#4143). Safe
	# because LinkNode always emits literal '+' as '%2B', so a title
	# like "C++" round-trips correctly either way.
	#
	# Order matters: transliterate '+' before %XX decoding so an encoded
	# '%2B' survives as a literal '+' in the result.
	my $decode = sub {
		my $s = shift;
		return '' unless defined $s;
		$s =~ tr/+/ /;
		$s =~ s/%([0-9a-fA-F]{2})/chr(hex($1))/ge;
		return $s;
	};

	# Order matters: more-specific patterns first so /user/X/writeups/Y
	# isn't shadowed by /user/X.
	if ($uri =~ m{^/?user/(.+?)/writeups/(.+?)/?$}) {
		$q->param('author', $decode->($1));
		$q->param('node',   $decode->($2));
		$q->param('type',   'writeup');
	}
	elsif ($uri =~ m{^/?user/(.+?)/writeups/?$}) {
		$q->param('usersearch', $decode->($1));
		$q->param('node',       'everything user search');
		$q->param('type',       'superdoc');
	}
	elsif ($uri =~ m{^/?user/(.+?)/?$}) {
		$q->param('node', $decode->($1));
		$q->param('type', 'user');
	}
	elsif ($uri =~ m{^/?s/([^/]+)/?$}) {
		# Short URL lookup. mod_perl rewrote ^/?s/([^/]+) ->
		# type=fullpage&node=Short+URL+Lookup&short_string=$1; without the
		# rewrite (PSGI) we recover it here so /s/<base49> still resolves to
		# its target node (Everything::Page::short_url_lookup). The short
		# string is base-49 [a-zA-Z0-9] so decoding is a no-op, but route it
		# through $decode for consistency.
		$q->param('type',         'fullpage');
		$q->param('node',         'Short URL Lookup');
		$q->param('short_string', $decode->($1));
	}
	elsif ($uri =~ m{^/?title/(.+?)/?$}) {
		$q->param('node', $decode->($1));
	}
	elsif ($uri =~ m{^/?e2node/(.+?)/?$}) {
		$q->param('node', $decode->($1));
	}
	elsif ($uri =~ m{^/?node/(\d+)/(\w+)/?$}) {
		# node_id + displaytype. Under mod_perl the apache rewrite
		# (^node/(\d+)/(\w+) -> node_id=$1&displaytype=$2) already put these
		# in the query string and this case was a deliberate no-op. Under
		# PSGI there is no such rewrite, so populate them here. Re-setting the
		# same values under mod_perl is harmless.
		$q->param('node_id',     $1);
		$q->param('displaytype', $2);
	}
	elsif ($uri =~ m{^/?node/(\d+)/?$}) {
		# Bare node_id. Same story: apache rewrote ^node/(\d+) -> node_id=$1
		# under mod_perl; without the rewrite (PSGI) we recover it from the
		# path. This is the /node/<id> permalink shape (e.g. the ?lastnode_id
		# softlink/SEO links).
		$q->param('node_id', $1);
	}
	elsif ($uri =~ m{^/?node/([^\d/][^/]*)/?$}) {
		$q->param('node', $decode->($1));
	}
	elsif ($uri =~ m{^/?node/([^/]+)/(.+?)/?$}) {
		# /node/<type>/<title>
		my ($type, $title) = ($1, $2);
		# Only recover if the first segment is a real type word, not a node_id —
		# numeric ids are already routed correctly.
		if ($type !~ /^\d+$/) {
			$q->param('type', $decode->($type));
			$q->param('node', $decode->($title));
		}
	}

	return;
}

#####################
# sub
#   process_vars_set
#
# purpose
#   Update package variables if a node was updated which affects them
#
# params
#   $updated_node -- the updated node
#
# returns
#   nothing
sub processVarsSet {
	my $updated_node = shift;

	if ($$updated_node{node_id} == $$USER{node_id}) {
		$VARS = getVars($updated_node);
	}

	return;
}

1;


#############################################################################
# End of package
#############################################################################
1;

