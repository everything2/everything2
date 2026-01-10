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
use Everything::Delegation::htmlcode;
use Everything::Delegation::opcode;

use Everything::Request;

use Encode;
use CGI qw(-utf8);
use CGI::Carp qw(set_die_handler);
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
              $PAGELOAD
              $query
              parseLinks
              htmlFormatErr
              urlGen
              getPage
              getPages
              getPageForType
              linkNode
              linkNodeTitle
              nodeName
              htmlcode
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
use vars qw($PAGELOAD);
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

    CORE::die(@_) if CGI::Carp::ineval();

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
			$error .= "\t- param: " . $_ . " = " . $query->param($_) . "\n";
		}
	}

	return $error;
}


sub encodeHTML
{
  return $APP->encodeHTML(@_);
}

#############################################################################
#	Sub
#		htmlFormatErr
#
#	Purpose
#		An error has occured and we need to print or log it.  This will
#		do the appropriate action based on who the user is.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlFormatErr
{
	my ($code, $err, $warn) = @_;

	my $dbg = getNode("debuggers", "usergroup");
	my $str = htmlErrorUsers($code, $err, $warn);

	if($DB->isApproved($USER, $dbg))
	{
		$str = htmlErrorGods($code, $err, $warn);
	}

	return $str;
}


#############################################################################
#	Sub
#		htmlErrorUsers
#
#	Purpose
#		Format an error for the general user.  In this case we do not
#		want them to see the error or the perl code.  So we will log
#		the error and give them a simple one.
#
#		You can define a custom error text by creating an htmlcode
#		node that formats a string error.  The code is passed a single
#		numeric value that can be used to reference the error that is
#		written to the log file.  However, be very careful that your
#		htmlcode for your custom message doesn't have an error, or
#		you may cause a user to get stuck in an infinite loop.  Since,
#		an error in that code would cause the system to call itself
#		to handle the error.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorUsers
{
	my ($code, $err, $warn) = @_;
	my $errorId = int(rand(9999999));  # just generate a random error id.

	my $str = "Server Error (Error Id $errorId)!";
	$str = "<font color=\"#CC0000\"><b>$str</b></font>";
	$str .= '<p id="servererror">An error has occured.  It has been logged. Apologies for the inconvenience. If it persists, contact an administrator</p>';

	# Print the error to the log instead of the browser.  That way users
	# do not see all the messy perl code.
	my $error = "Server Error (#" . $errorId . ")\n";
	if ($GNODE) { $error .= "Node: $$GNODE{title}\n"; }
	else { $error .= "Node: null\n"; }

	if ($USER) { $error .= "User: $$USER{title}\n"; }
	else { $error .= "User: null\n"; }
	$error .= "User agent: " . $query->user_agent() . "\n" if defined $query;
	$error .= "Code:\n$code\n";
	$error .= "Error:\n$err\n";
	$error .= "Warning:\n$warn";
	$error .= "Params:\n";
	$error .= query_vars_string();
	$error .= longmess();
	Everything::printLog($error);

	return $str;
}


#############################################################################
#	Sub
#		htmlErrorGods
#
#	Purpose
#		Print an error for a god user.  This will dump the code, the call
#		stack and any other error information.  You probably don't want
#		the average user of a site to see this stuff.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorGods
{
	my ($code, $err, $warn) = @_;
	my $error = $err . $warn;
	my $linenum;

	$code = $APP->encodeHTML($code);

	my @mycode = split /\n/, $code;
	while($error =~ /line (\d+)/sg)
	{
		# If the error line is within the range of the offending code
		# snipit, make it red.  The line number may actually be from
		# a perl module that the evaled code is calling.  If thats the
		# case, we don't want some bogus number to add lines.
		if($1 < (scalar @mycode))
		{
			# This highlights the offendling line in red.
			$mycode[$1-1] = "<FONT color=cc0000><b>" . $mycode[$1-1] .
				"</b></font>";
		}
	}

	my $str = "<dl>\n"
		. "<dt>Error:</dt><dd>"
		. $APP->encodeHTML($err)
		. "</dd>\n"
		. "<dt>Warning:</dt><dd>"
		. $APP->encodeHTML($warn)
		. "</dd>\n"
		;

	my $count = 1;
	$str .= "<dt>Code</dt><dd><pre>";
	foreach my $line (@mycode)
	{
		$str .= sprintf("%4d: ", $count) . "$line\n";
		$count++;
	}

	# Print the callstack to the browser too, so we can see where this
	# is coming from.
	my $ignoreMe = 3;
	$str .= "\n\n<b>Call Stack</b>:\n";
	$str .= (join "\n", reverse $APP->getCallStack($ignoreMe));
	$str .= "\n<b>End Call Stack</b>\n";

	$str.= "</pre></dd>";
	$str.="</dl>\n";
	return $str;
}

sub urlGen
{
  return $APP->urlGen(@_);
}

#############################################################################
#	Sub
#		getPages
#
#	Purpose
#		This gets the edit and display pages for the given node.  Since
#		nodetypes can be inherited, we need to find the display/edit pages.
#
#		If the given node is a nodetype, it will get the display pages for
#		that particular nodetype rather than the main 'nodetype'.
#		Difference is subtle between this function and getPage().  If you
#		pass a nodetype to getPage() it will return the htmlpages to display
#		it, while this will return the htmlpages needed to display nodes
#		of the type passed in.
#
#		For example, lets say you pass the nodetype 'document' to both
#		this and getPage().  This would return 'document display page'
#		and 'document edit page', while getPage would return 'nodetype
#		dipslay page' and 'nodetype edit page'.
#
#	Parameters
#		$NODE - the nodetype in which to get the display/edit pages for.
#
#	Returns
#		An array containing the display/edit pages for this nodetype.
#
sub getPages
{
	my ($NODE) = @_;
	getRef $NODE;
	my $TYPE;
	my @pages;

	$TYPE = $NODE if (isNodetype($NODE) && $$NODE{extends_nodetype});
	$TYPE ||= getType($$NODE{type_nodetype});

	push @pages, getPageForType($TYPE, "display");
	push @pages, getPageForType($TYPE, "edit");

	return @pages;
}

#############################################################################
#	Sub
#		getPageForType
#
#	Purpose
#		Given a nodetype, get the htmlpages needed to display nodes of this
#		type.  This runs up the nodetype inheritance hierarchy until it
#		finds something.
#
#	Parameters
#		$TYPE - the nodetype hash to get display pages for.
#		$displaytype - the type of display (usually 'display' or 'edit')
#
#	Returns
#		A node hashref to the page that can display nodes of this nodetype.
#
sub getPageForType
{
	my ($TYPE, $displaytype) = @_;
	my %WHEREHASH;
	my $PAGE;
	my $ORIGTYPE = int $$TYPE{node_id};
	my $PAGETYPE;

	$PAGETYPE = getType("htmlpage");
	$PAGETYPE or die "HTML PAGES NOT LOADED!";

	# Starting with the nodetype of the given node, We run up the
	# nodetype inheritance hierarchy looking for some nodetype that
	# does have a display page.
	do
	{
		# Clear the hash for a new search
		undef %WHEREHASH;
		
		%WHEREHASH = ( -pagetype_nodetype => $$TYPE{node_id},
				displaytype => $displaytype);
		

		($PAGE) = getNodeWhere(\%WHEREHASH, $PAGETYPE) unless $PAGE;

		if(not defined $PAGE)
		{
			if($$TYPE{extends_nodetype})
			{
				$TYPE = getType($$TYPE{extends_nodetype});
			}
			else
			{

			# No pages for the specified nodetype were found.
				# Use the default node display.
				($PAGE) = getNodeWhere (
						{ -pagetype_nodetype => getId(getType("node")),
						displaytype => $displaytype}, 
						$PAGETYPE);

				$PAGE or ($PAGE) =  getNodeWhere(
						{ -pagetype_nodetype => $ORIGTYPE,
						displaytype => "display" },
						$PAGETYPE );
				$PAGE or ($PAGE) = getNodeWhere(
						{ -pagetype_nodetype => getId(getType("node")),
						  displaytype => "display"},
						$PAGETYPE);
			}
		}
	} until($PAGE);

	return $PAGE;
}


#############################################################################
#	Sub
#		getPage
#
#	Purpose
#		This gets the htmlpage of the specified display type for this
#		node.  An htmlpage is basically a database form that knows
#		how to display the information for a particular nodetype.
#
#	Parameters
#		$NODE - a node hash of the node that we want to get the htmlpage for
#		$displaytype - the type of display of the htmlpage (usually
#			'display' or 'edit')
#
#	Returns
#		The node hash of the htmlpage for this node.  If none can be
#		found it uses the basic node display page.
#
sub getPage
{
	my ($NODE, $displaytype) = @_; 
	my $TYPE;
	
	getRef $NODE;
	$TYPE = getType($$NODE{type_nodetype});
	$displaytype ||= 'display';

	my $PAGE = getPageForType $TYPE, $displaytype;
	$PAGE ||= getPageForType $TYPE, 'display';

	die "can't load a page $displaytype for $$TYPE{title} type" unless $PAGE;

	return $PAGE;
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
#	sub htmlcode
#
#	purpose
#		allow for easy use of htmlcode functions in embedded perl
#
#	args
#		[0] the function name
#		[1] the arguments in a comma delimited list (must be string), or
#			more than one argument: can be anything
#
#
sub htmlcode {
	my ($splitter, $returnVal) = ('');
	my @returnArray;
	my $encodedArgs = "(no arguments)";
	my $htmlcodeName = shift;


	# localize @_ to insure encodeHTML doesn't mess with our args
	my @savedArgs = @_;

	# Old-style htmlcode call. We will eventually change the way this works
	# By creating an embedded htmlcode entrypoint which is smarter about doing the split
	# But for now, emulate the old behavior

	if(scalar(@savedArgs) == 1 && !ref($savedArgs[0]) && defined($savedArgs[0]))
	{
		@savedArgs = split(/\s*,\s*/, $savedArgs[0]);
	}

	$encodedArgs = $APP->encodeHTML($encodedArgs);

	my $delegation_name = $htmlcodeName;
	$delegation_name =~ s/[\s\-]/_/g;

	if(my $delegation = Everything::Delegation::htmlcode->can($delegation_name))
	{
		if(wantarray) {
			@returnArray = $delegation->($DB, $query, $GNODE, $USER, $VARS, $PAGELOAD, $APP, @savedArgs);
		}else{
			$returnVal = $delegation->($DB, $query, $GNODE, $USER, $VARS, $PAGELOAD, $APP, @savedArgs);
		}
	}else{
                return htmlFormatErr("","$htmlcodeName could not be found as Everything::Delegation::htmlcode::$delegation_name");
	}

	if (wantarray) {
		return @returnArray;
	} else {
		return $returnVal;
	}
}

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
	my $PAGE = getPage($NODE, $displaytype);
	$NODE->{datatype} = $PAGE->{mimetype};

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

	my $updateAllowed = !$no_update && canUpdateNode($user_id, $NODE);

	if ($updateAllowed && $$NODE{type}{verify_edits}) {
		my $type = $$NODE{type}{title};
		if (!htmlcode('verifyRequest', "edit_$type")) {

			$updateAllowed = 0;

			# Blank the passed values if this looks like an XSRF
			if ($query->param('add') || $query->param('group')
				|| (grep { /^${type}_/ } $query->Vars)) {
				$query->delete_all();
			}
		}
	}

	if ($updateAllowed) {
		if (my $groupadd = $query->param('add')) {
			insertIntoNodegroup($NODE, $user_id, $groupadd,
				$query->param('orderby'));
		}
		
		if ($query->param('group')) {
			my @newgroup;

			my $counter = 0;
			while (my $item = $query->param($counter++)) {
				push @newgroup, $item;
			}

			replaceNodegroup ($NODE, \@newgroup, $user_id);
		}

		my @updatefields = $query->param;
		my $updateflag;

		my $RESTRICTED = getVars(getNode('restricted fields', 'setting'));
		$RESTRICTED ||= {};
		foreach my $field (@updatefields) {
			if ($field =~ /^$$NODE{type}{title}\_(\w*)$/) {
				next if exists $$RESTRICTED{$1} or exists $$RESTRICTED{"$$NODE{type}{title}\_$1"};	
				$$NODE{$1} = $query->param($field);
				$updateflag = 1;
			}	
		}
		if ($updateflag) {
			updateNode($NODE, $USER); 
			if (getId($USER) == getId($NODE)) { $USER = $NODE; }
		}
	}
	

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
		my $redirQuery = new CGI($query);
		my $safeToRedirect = 1;
		$redirQuery->delete('op') if $redirQuery->param('op') eq "";
		foreach ($redirQuery->param) {
			$safeToRedirect = 0 unless defined $NO_SIDE_EFFECT_PARAMS{$_};
			$redirQuery->delete($_) if(defined($NO_SIDE_EFFECT_PARAMS{$_}) and $NO_SIDE_EFFECT_PARAMS{$_} eq 'delete');
		}

		if ($safeToRedirect) {
			my $noQuotes = 1;

			# Generate relative URL without hostname/port for proper development environment support
			my $url = urlGen({%{$redirQuery->Vars}}, $noQuotes, $NODE);

			$redirQuery->redirect(
				-uri => $url
				, -nph => 0
				, -status => 303
				, -Cache_Control => 'private, no-cache, no-store'
			);
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
#	Sub
#		printHeader
#
#	Purpose
#		For each page we serve, we need to pass standard HTML header
#		information.  If we are script, we are responsible for doing
#		this (the web server has no idea what kind of information we
#		are passing).
#
#	Parameters
#		$datatype - (optional) the MIME type of the data that we are
#			to display	('image/gif', 'text/html', etc).  If not
#			provided, the header will default to 'text/html'.
#
sub printHeader
{
	my ($datatype, $page, $lastnode) = @_;

 	my $len = length $page;
	# default to plain html
	$datatype = "text/html" unless $datatype;
	my @cookies = ();

	if ($lastnode && $lastnode > 0) {
		push @cookies, $query->cookie( -name=>'lastnode_id', -value=>'');

	} elsif ($lastnode && $lastnode == -1) {

	} else {
		push @cookies, $query->cookie('lastnode_id', '');
	}
	if ($$USER{cookie}) {
		push @cookies, $$USER{cookie};
	}

	my $extras = {};
	$extras->{charset} = 'utf-8';
	if(@cookies)
	{
		$extras->{cookie} = \@cookies;
	}

        if(my $best_compression = $APP->best_compression_type)
        {
		$extras->{content_encoding} = $best_compression;
        }

        $extras->{'X-Frame-Options'} = "sameorigin";

        # Set Cache-Control based on user login state and cookie presence
        # Logged-in users get private, no-cache to prevent CloudFront caching
        # This ensures user-specific content (random nodes, personal data) is fresh
        # Also force no-cache when setting cookies (e.g., logout) to prevent
        # CloudFront from caching and stripping the Set-Cookie header
        if ($$USER{cookie} || !$APP->isGuest($USER)) {
            # Setting cookies or logged-in users should never be cached
            $extras->{'Cache-Control'} = "private, no-cache, no-store, must-revalidate";
        } else {
            # Guests without cookie changes can be cached by CloudFront
            $extras->{'Cache-Control'} = "public, max-age=300";
        }

	if($ENV{SCRIPT_NAME}) {
		$query->header(-type=> $datatype,
			       -content_length => $len,
			       %HEADER_PARAMS,%$extras);
	}

	return;
}


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
    my $type  = $query->param('type');

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
        $PAGELOAD = {};
	$query = "";
	$REQUEST = undef;

	return;
}


#############################################################################
sub opNuke
{
	my $user_id = $$USER{node_id};
	my $node_id = $query->param("node_id");

	return if $APP->getParameter($node_id, "prevent_nuke");
	return nukeNode($node_id, $user_id);
}


#############################################################################
#	Sub
#		opLogin
#
#	Purpose
#		log in user with plain text password and set login cookie
#		with username and hashed password
#

sub opLogin
{
  my $user = $query->param("user");
  $user = "" if not defined($user);

  my $pass = $query->param("passwd");
  $pass = "" if not defined($pass);

  $USER = $REQUEST->login("username" => $user, "pass" => $pass)->NODEDATA;
  $VARS = $REQUEST->user->VARS;
  return;
}

#############################################################################
sub opLogout
{
	# The user is logging out.  Nuke their cookie.
	# Must set expires to past date for browser to actually delete the cookie
	my $cookie = $query->cookie(
		-name => $Everything::CONF->cookiepass,
		-value => "",
		-expires => '-1d',
		-path => '/'
	);
	my $user_id = $Everything::CONF->guest_user;

	$USER = getNodeById($user_id);
	$VARS = getVars($USER);

	$$USER{cookie} = $cookie if($cookie);

	$REQUEST->logout;
	return;
}


#############################################################################
sub opNew
{
	my $node_id = 0;
	my $user_id = $$USER{node_id};
	my $type = $query->param('type');
	my $TYPE = getType($type);
	my $removeSpaces = 1;
	my $nodename = $APP->cleanNodeName(scalar($query->param('node')), $removeSpaces);

	if (canCreateNode($user_id, $DB->getType($type)) and not $APP->isGuest($USER))
	{
		$node_id = insertNode($nodename,$TYPE, $user_id);

		if($node_id == 0)
		{
			# It appears that the node already exists.  Get its id.
			$node_id = $DB->sqlSelect("node_id", "node", "title=" .
				$DB->quote($nodename) . " && type_nodetype=" .
				$$TYPE{node_id});
		}

		$query->param("node_id", $node_id);
		$query->param("node", "");
	} 
	else
	{
		$query->param("node_id", $Everything::CONF->permission_denied);
	}

	return;
}


#############################################################################
#	Sub
#		execOpCode
#
#	Purpose
#		One of the CGI parameters that can be passed to Everything is the
#		'op' parameter.  "Operations" are discrete pieces of work that are
#		to be executed before the page is displayed.  They are useful for
#		providing functionality that can be shared from any node.
#
#		By creating an opcode node you can create new ops or override the
#		defaults.  Just becareful if you override any default operations.
#		For example, if you override the 'login' op with a broken
#		implementation you may not be able to log in.
#
#	Parameters
#		None
#
#	Returns
#		Nothing
#
sub execOpCode
{
  my $op = $query->param('op');
  my $handled = 0;

  return 0 unless(defined $op && $op ne "");
  my $delegation = undef;
  if($op ne "new" and $delegation = Everything::Delegation::opcode->can($op))
  {
    $APP->devLog("Using delegated opcode: $op");
    $delegation->($DB, $query, $GNODE, $USER, $VARS, $PAGELOAD, $APP);
    return;
  }

  # These are built in defaults.  If no 'opcode' nodes exist for
  # the specified op, we have some default handlers.

  if($op eq 'login')
  {
    opLogin()
  }elsif($op eq 'logout')
  {
    opLogout();
  }elsif($op eq 'nuke')
  {
    opNuke();
  }elsif($op eq 'new')
  {
    opNew();
  }

  return;
}

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

	set_die_handler(\&handle_errors);

	$query = $REQUEST->cgi;

	$USER = $REQUEST->user->NODEDATA;
    $VARS = $REQUEST->user->VARS;
	$PAGELOAD = $REQUEST->PAGELOAD;

         #only for Everything2.com
         if ($query->param("op") eq "randomnode") {
               $query->param("node_id", $APP->getRandomNodesMany(1)->[0]->{node_id});
         }

	$APP->refreshVotesAndCools($USER, $VARS);

	# Execute any operations that we may have
	execOpCode();

	# Do the work.
	handleUserRequest();

	$DB->closeTransaction();
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

