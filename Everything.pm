#something stupid

package Everything;

#############################################################################
#	Everything perl module.  
#	Copyright 1999 Everything Development
#	http://www.everydevel.com
#
#	Format: tabs = 4 spaces
#
#	General Notes
#		Functions that start with 'select' only return the node id's.
#		Functions that start with 'get' return node hashes.
#
#############################################################################

use strict;
use DBI;
use Everything::NodeBase;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
              %CONFIG
              $DB
              $dbh
              getRef
              getId
              getTables

              getNode
              getNodeById
              getType
              getNodeWhere
              selectNodeWhere
              selectNode

              nukeNode
              insertNode
              updateNode
              replaceNode

              initEverything
              removeFromNodegroup
              replaceNodegroup
              insertIntoNodegroup
              canCreateNode
              canDeleteNode
              canUpdateNode
              canReadNode
              updateLinks
              updateHits
              getVars
              setVars
              selectLinks
              isGroup
              isNodetype
              isGod
              lockNode
              unlockNode

              dumpCallStack
              getCallStack
              printErr
              printLog
            );
 }

use vars qw($DB);
use vars qw($PERLTIME);
use vars qw($SQLTIME);


# $dbh is deprecated.  Use $DB->getDatabaseHandle() to get the DBI interface
use vars qw($dbh);

# If you want to log to a different file, change this.
my $everythingLog = "/tmp/everything.errlog";

# Used by Makefile.PL to determine the version of the install.
my $VERSION = 0.8;


#############################################################################
#
#   a few wrapper functions for the NodeBase stuff
#	this allows the $DB to be optional for the general node functions
#
sub getNode			{ $DB->getNode(@_); }
sub getNodeById		{ $DB->getNodeById(@_); }
sub getType 		{ $DB->getType(@_); }
sub getNodeWhere 	{ $DB->getNodeWhere(@_); }
sub selectNodeWhere	{ $DB->selectNodeWhere(@_); }
sub selectNode		{ $DB->getNodeById(@_); }

sub nukeNode		{ $DB->nukeNode(@_);}
sub insertNode		{ $DB->insertNode(@_); }
sub updateNode		{ $DB->updateNode(@_); }
sub replaceNode		{ $DB->replaceNode(@_); }

sub isNodetype		{ $DB->isNodetype(@_); }
sub isGroup			{ $DB->isGroup(@_); }
sub isGod			{ $DB->isGod(@_); }
sub isApproved		{ $DB->isApproved(@_); }

#############################################################################
sub printErr {
	print STDERR $_[0]; 
}


#############################################################################
#	Sub
#		getTime
#
#	Purpose
#		Quickie function to get a date and time string in a nice format.
#
sub getTime
{
	my $time = `/bin/date +"%a %b %d %R%p"`;
	chomp $time;
	return $time;
}


#############################################################################
#	Sub
#		printLog
#
#	Purpose
#		Debugging utiltiy that will write the given string to the everything
#		log (aka "elog").  Each entry is prefixed with the time and date
#		to make for easy debugging.
#
#	Parameters
#		entry - the string to print to the log.  No ending carriage return
#			is needed.
#
sub printLog
{
	my $entry = $_[0];
	my $time = getTime();
	
	# prefix the date a time on the log entry.
	$entry = "$time: $entry\n";

	if(open(ELOG, ">> $everythingLog"))
	{
		print ELOG $entry;
		close(ELOG);
	}

	return 1;
}


#############################################################################
#	Sub
#		clearLog
#
#	Purpose
#		Clear the gosh darn log!
#
sub clearLog
{
	my $time = getTime();

	`echo "$time: Everything log cleared" > $everythingLog`;
}


#############################################################################
#	Sub
#		getRef
#
#	Purpose
#		This makes sure that we have an array of node hashes, not node id's.
#
#	Parameters
#		Any number of node id's or node hashes (ie getRef( $n[0], $n[1], ...))
#
#	Returns
#		The node hash of the first element passed in.
#
sub getRef
{
	return $DB->getRef(@_);
}


#############################################################################
#	Sub
#		getId
#
#	Purpose
#		Opposite of getRef.  This makes sure we have node id's not hashes.
#
#	Parameters
#		Array of node hashes to convert to id's
#
#	Returns
#		An array (if there are more than one to be converted) of node id's.
#
sub getId
{
	return $DB->getId(@_);
}


#############################################################################
#	Sub
#		escape
#
#	Purpose
#		This encodes characters that may interfere with HTML/perl/sql
#		into a hex number preceeded by a '%'.  This is the standard HTML
#		thing to do when uncoding URLs.
#
#	Parameters
#		$esc - the string to encode.
#
#	Returns
#		Then escaped string
#
sub escape
{
	my ($esc) = @_;

	$esc =~ s/(\W)/sprintf("%%%02x",ord($1))/ge;
	
	return $esc;
}


#############################################################################
#	Sub
#		unescape
#
#	Purpose
#		Convert the escaped characters back to normal ascii.  See escape().
#
#	Parameters
#		An array of strings to convert
#
#	Returns
#		Nothing useful.  The array elements are changed.
#
sub unescape
{
	foreach my $arg (@_)
	{
		tr/+/ /;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}
	
	1;
}


#############################################################################
sub getVars 
{
	my ($NODE) = @_;
	getRef $NODE;

	return if ($NODE == -1);
	return unless $NODE;
	
	unless (exists $$NODE{vars}) {
		warn ("getVars:\t'vars' field does not exist for node ".getId($NODE)."
		perhaps it doesn't join on the settings table?\n");
	}

	#if($DB->{cache}->{hashCache}->{$$NODE{node_id}} and $$NODE{type}{title} ne "theme")
	#{
	#	return $DB->{cache}->{hashCache}->{$$NODE{node_id}};
	#}

	my %vars;
	return \%vars unless ($$NODE{vars});

	%vars = map { split /=/ } split (/&/, $$NODE{vars});
	foreach (keys %vars) {
		unescape $vars{$_};
		if ($vars{$_} eq ' ') { $vars{$_} = ""; }
	}

	#delete $vars{themesetting_id};
	my %varscopy = %vars;

	$DB->{cache}->{hashCache}->{$$NODE{node_id}} = \%varscopy;
	\%vars;
}


#############################################################################
#	Sub
#		setVars
#
#	Purpose
#		This takes a hash of variables and assigns it to the 'vars' of the
#		given node.  If the new vars are different, we will update the
#		node.
#
#	Parameters
#		$NODE - a node id or hash of a node that joins on the
#		"settings" table which has a "vars" field to assign the vars to.
#		$varsref - the hashref to get the vars from
#
#	Returns
#		Nothing
#
sub setVars
{
	my ($NODE, $varsref) = @_;
	my $str;

	getRef($NODE);

	unless (exists $$NODE{vars}) {
		warn ("setVars:\t'vars' field does not exist for node ".getId($NODE)."
		perhaps it doesn't join on the settings table?\n");
	}

	# Clean out the keys that have do not have a value.
	foreach (keys %$varsref) {
		$$varsref{$_} = " " unless $$varsref{$_};
	}
	
	$str = join("&", map( $_."=".escape($$varsref{$_}), keys %$varsref) );

	return unless ($str ne $$NODE{vars}); #we don't need to update...

	# The new vars are different from what this user node contains, force
	# an update on the user info.
	$$NODE{vars} = $str;
	#undef $DB->{cache}->{hashCache}->{$$NODE{node_id}};
	my $superuser = -1;
	$DB->updateNode($NODE, $superuser, 1);
}


#############################################################################
sub canCreateNode
{
	return $DB->canCreateNode(@_);
}


#############################################################################
sub canDeleteNode
{
	return $DB->canDeleteNode(@_);
}


#############################################################################
sub canUpdateNode
{
	return $DB->canUpdateNode(@_);
}


#############################################################################
sub canReadNode
{ 
	return $DB->canReadNode(@_);
}


#############################################################################
#	Sub
#		insertIntoNodegroup
#
#	Purpose
#		This will insert a node(s) into a nodegroup.
#
#	Parameters
#		NODE - the group node to insert the nodes.
#		USER - the user trying to add to the group (used for authorization)
#		insert - the node or array of nodes to insert into the group
#		orderby - the criteria of which to order the nodes in the group
#
#	Returns
#		The group NODE hash that has been refreshed after the insert
#
sub insertIntoNodegroup
{
	return ($DB->insertIntoNodegroup(@_));
}


#############################################################################
#	Sub
#		selectNodegroupFlat
#
#	Purpose
#		This recurses through the nodes and node groups that this group
#		contains getting the node hash for each one on the way.
#
#	Parameters
#		$NODE - the group node to get node hashes for.
#
#	Returns
#		An array of node hashes that belong to this group.
#
sub selectNodegroupFlat
{
	return $DB->selectNodegroupFlat(@_);
}


#############################################################################
#	Sub
#		removeFromNodegroup
#
#	Purpose
#		Remove a node from a group.
#
#	Parameters
#		$GROUP - the group in which to remove the node from
#		$NODE - the node to remove
#		$USER - the user who is trying to do this (used for authorization)
#
#	Returns
#		The newly refreshed nodegroup hash.  If you had called
#		selectNodegroupFlat on this before, you will need to do it again
#		as all data will have been blown away by the forced refresh.
#
sub removeFromNodegroup 
{
	return $DB->removeFromNodegroup(@_);
}


#############################################################################
#	Sub
#		replaceNodegroup
#
#	Purpose
#		This removes all nodes from the group and inserts new nodes.
#
#	Parameters
#		$GROUP - the group to clean out and insert new nodes
#		$REPLACE - A node or array of nodes to be inserted
#		$USER - the user trying to do this (used for authorization).
#
#	Returns
#		The group NODE hash that has been refreshed after the insert
#
sub replaceNodegroup
{
	return $DB->replaceNodegroup(@_);
}


#############################################################################
#	Sub
#		updateLinks
#
#	Purpose
#		A link has been traversed.  If it exists, increment its hit and
#		food count.  If it does not exist, add it.
#
#		DPB 24-Sep-99: We need to better define how food gets allocated to
#		to links.  I think t should be in the system vars somehow.
#
#	Parameters
#		$TONODE - the node the link goes to
#		$FROMNODE - the node the link comes from
#		$type - the type of the link (not sure what this is, as of 24-Sep-99
#			no one uses this parameter)
#
#	Returns
#		nothing of use
#
sub updateLinks
{
	my ($TONODE, $FROMNODE, $type) = @_;
	return if getId($TONODE) == getId($FROMNODE) and not $type;
	getRef $TONODE;
	getRef $FROMNODE;
	
	#return if getId($USER) == $HTMLVARS{guest_user};
	return unless ($$TONODE{type}{title} eq 'e2node' and $$FROMNODE{type}{title} eq 'e2node') or $type;


	$type ||= 0;
	$type = getId $type;
	my $to_id = getId $TONODE;
	my $from_id = getId $FROMNODE;

	my $rows = $DB->sqlUpdate('links',
			{ -hits => 'hits+1' ,  -food => 'food+1'}, 
			"from_node=$from_id && to_node=$to_id && linktype=" .
			$DB->getDatabaseHandle()->quote($type));

	if ($rows eq "0E0") { 
		$DB->sqlInsert("links", {'from_node' => $from_id, 'to_node' => $to_id, 
				'linktype' => $type, 'hits' => 1, 'food' => '500' }); 
		$DB->sqlInsert("links", {'from_node' => $to_id, 'to_node' => $from_id, 
				'linktype' => $type, 'hits' => 1, 'food' => '500' }); 
	}
}


#############################################################################
#   Sub
#       updateHits
#
#   Purpose
#       Increment the number of hits on a node.
#
#   Parameters
#       $NODE - the node in which to update the hits on
#
#   Returns
#       The new number of hits
#
sub updateHits
{
	my ($NODE) = @_;
	my $id = $$NODE{node_id};

	$DB->sqlUpdate('hits', { -hits => 'hits+1' }, "node_id=$id");

	# We will just do this, instead of doing a complete refresh of the node.
#	++$$NODE{hits};
}


#############################################################################
#	Sub
#		selectLinks - should be named getLinks since it returns a hash
#
#	Purpose
#		Gets an array of hashes for the links that originate from this
#		node (basically, the list of links that are on this page).
#
#	Parameters
#		$FROMNODE - the node we want to get links for
#		$orderby - the field in which the sql should order the list
#
#	Returns
#		A reference to an array that contains the links
#
sub selectLinks
{
	my ($FROMNODE, $orderby) = @_;

	my $obstr = "";
	my @links;
	my $cursor;
	
	$obstr = " ORDER BY $orderby" if $orderby;

	$cursor = $DB->sqlSelectMany ("*", 'links use index (linktype_fromnode_hits) ',
		"from_node=". $DB->getDatabaseHandle()->quote(getId($FROMNODE)) .
		$obstr); 
	
	while (my $linkref = $cursor->fetchrow_hashref())
	{
		push @links, $linkref;
	}
	
	$cursor->finish;
	
	return \@links;
}


#############################################################################
#	Sub
#		cleanLinks
#
#	Purpose
#		Sometimes the links table gets stale with pointers to nodes that
#		do not exist.  This will go through and delete all of the links
#		rows that point to non-existant nodes.
#
#		NOTE!  If the links table is large, this could take a while.  So,
#		don't be calling this after every node update, or anything like
#		that.  This should be used as a maintanence function.
#
#	Parameters
#		None.
#
#	Returns
#		Number of links rows removed
#
sub cleanLinks
{
	my $select;
	my $cursor;
	my $row;
	my @to_array;
	my @from_array;
	my $badlink;

	$select = "SELECT to_node,node_id from links";
	$select .= " left join node on to_node=node_id";

	$cursor = $DB->getDatabaseHandle()->prepare($select);

	if($cursor->execute())
	{
		while($row = $cursor->fetchrow_hashref())
		{
			if(not $$row{node_id})
			{
				# No match.  This is a bad link.
				push @to_array, $$row{to_node};
			}
		}
	}

	$select = "SELECT from_node,node_id from links";
	$select .= " left join node on from_node=node_id";

	$cursor = $DB->getDatabaseHandle()->prepare($select);

	if($cursor->execute())
	{
		while($row = $cursor->fetchrow_hashref())
		{
			if(not $$row{node_id})
			{
				# No match.  This is a bad link.
				push @from_array, $$row{to_node};
			}
		}
	}

	foreach $badlink (@to_array)
	{
		$DB->sqlDelete("links", { to_node => $badlink });
	}

	foreach $badlink (@from_array)
	{
		$DB->sqlDelete("links", { from_node => $badlink });
	}
}


#############################################################################
sub lockNode {
	my ($NODE, $USER)=@_;

	1;
}


#############################################################################
sub unlockNode {
	my ($NODE, $USER)=@_;


	1;
}


#############################################################################
#	Sub
#		initEverything
#
#	Purpose
#		The "main" function.  Initialize the Everything module.
#
#	Parameters
#		$db - the string name of the database to connect to.
#		$staticNodetypes - (optional) 1 if the system should derive the
#			nodetypes once and cache them.  This will speed performance,
#			but changes to nodetypes will not take effect until the httpd
#			is restarted.  A really good performance enhancement IF the
#			nodetypes do not change.
#
sub initEverything
{
	my ($db, $staticNodetypes, $memcache) = @_;

  #Move some config settings to an external file instead of hardcoding
  #it into ecore. --[Swap]
  use Config::Simple;
  Config::Simple -> import_from('/etc/everything/everything.conf',\%CONFIG);

	$DB = new Everything::NodeBase($db, $staticNodetypes, $memcache);

	# This is for legacy code.  You should not use $dbh!  Use
	# $DB->getDatabaseHandle() going forward.
	$dbh = $DB->getDatabaseHandle();
}


#############################################################################
#	Sub
#		searchNodeName
#
#	Purpose
#		This is the node search function.  You give a search string
#		containing the words that you want, and this returns a list
#		of nodes (just the node table info, not the complete node).
#		The list is ordered such that the best matches come first.
#
#		NOTE!!! There are many things we can do in here to beef this
#		up.  Like adding a dictionary check on the words submitted
#		so that if a user can't spell we can at least get what they
#		might mean.
#
#	Parameters
#		$searchWords - the search string to use to find node matches.
#		$TYPE - an array of nodetype IDs of the types that we want to
#			restrict the search (useful for only returning results of a
#			particular nodetype.
#
#	Returns
#		A sorted list of node hashes (just the node table info), in
#		order of best matches to worst matches.
#
sub searchNodeName {
	my ($searchWords, $TYPE) = @_;
	my $typestr = '';

	$TYPE=[$TYPE] if (ref($TYPE) eq 'HASH');

	if(ref($TYPE) eq 'ARRAY' and @$TYPE) {
		my $t = shift @$TYPE;
		$typestr .= "AND (type_nodetype = " . getId($t);
		foreach(@$TYPE) { $typestr .= " OR type_nodetype = ". getId($_); }
		$typestr.=')';
	}
	my @prewords = split ' ', $searchWords;
	my @words;

	my $NOSEARCH = $DB->getNode('nosearchwords', 'setting');
	my $NOWORDS = getVars $NOSEARCH if $NOSEARCH;

	foreach (@prewords) {
		push(@words, $_) unless (exists $$NOWORDS{lc($_)} or length($_) < 2);
	}

	return unless @words;

	my $match = "";
	foreach my $word (@words) {
		$word = lc($word);
		$word =~ s/(\W)/\\$1/gs;
		$word = '[[:<:]]'.$word.'[[:>:]]';
		$word = "(lower(title) rlike ".$dbh->quote($word).")";
	}


	$match = '('. join(' + ',@words).')';
	my $cursor = $DB->sqlSelectMany("*, $match AS matchval",
		"node",
		"$match >= 1 $typestr", "ORDER BY matchval DESC");
	
	my @ret;
	while(my $m = $cursor->fetchrow_hashref) { push @ret, $m; }
	return \@ret;
}



#############################################################################
#	Sub
#		getTables
#
#	Purpose
#		Get the tables that a particular node(type) needs to join on
#
#	Parameters
#		$NODE - the node we are wanting tables for.
#
#	Returns
#		An array of the table names that this node joins on.
#
sub getTables
{
	my ($NODE) = @_;
	getRef $NODE;
	my @tmpArray = @{ $$NODE{type}{tableArray}};  # Make a copy

	return @tmpArray;
}


#############################################################################
#	Sub
#		dumpCallStack
#
#	Purpose
#		Debugging utility.  Calling this function will print the current
#		call stack to stdout.  Its useful to see where a function is
#		being called from.
#
sub dumpCallStack
{
	my @callStack;
	my $func;
	
	@callStack = getCallStack();
	
	# Pop this function off the stack.  We don't need to see "dumpCallStack"
	# in the stack output.
	pop @callStack;
	
	print "*** Start Call Stack ***\n";
	while($func = pop @callStack)
	{
		print "$func\n";
	}
	print "*** End Call Stack ***\n";
}


#############################################################################
#	
sub getCallStack
{
	my ($package, $file, $line, $subname, $hashargs);
	my @callStack;
	my $i = 0;
	
	while(($package, $file, $line, $subname, $hashargs) = caller($i++))
	{
		# We unshift it so that we can use "pop" to get them in the
		# desired order.
		unshift @callStack, "$file:$line:$subname";
	}

	# Get rid of this function.  We don't need to see "getCallStack" in
	# the stack.
	pop @callStack;

	return @callStack;
}


#############################################################################
# end of package
#############################################################################

1;
