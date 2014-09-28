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
use DateTime;
use Everything::NodeBase;
use Everything::Application;
use JSON;
use Devel::Caller qw(caller_args);

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $CONF);
	@ISA=qw(Exporter);
	@EXPORT=qw(
              $APP
              $DB
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
              updateLockedNode
              replaceNode
              transactionWrap

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

              dumpCallStack
              getCallStack
              printErr
              printLog

              commonLogLine
            );

	my $json_config = "/etc/everything/everything.conf.json";
	my ($json_handle, $json_data);
	open $json_handle, $json_config;
	{
		local $/ = undef;
		$json_data = <$json_handle>;
	}
	close $json_handle;
	$CONF = JSON::from_json($json_data);
}

use vars qw($DB);
use vars qw($APP);

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
sub updateLockedNode	{ $DB->updateLockedNode(@_); }
sub replaceNode		{ $DB->replaceNode(@_); }
sub transactionWrap	{ $DB->transactionWrap(@_); }

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
	my $dt = DateTime->now();
	return $dt->strftime("%a %b %d %R%p");
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

	if(open(ELOG, ">> ".getELogName()))
	{
		print ELOG $entry;
		close(ELOG);
	}

	return 1;
}

sub getELogName
{
	my $basedir = $Everything::CONF->{logdirectory};
	my $thistime = [gmtime()];
	my $datestr = $thistime->[5]+1900;
	$datestr .= sprintf("%02d",$thistime->[4]+1);
	$datestr .= sprintf("%02d",$thistime->[3]);
	$datestr .= sprintf("%02d",$thistime->[2]);

	return "$basedir/e2app.$datestr.log";
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


# This is an inlined, slightly sped up version of above. About a 2x perf improvement
# The above is only kept until we are sure that it is no longer needed

sub getVarHashFromStringFast
{
  return $APP->getVarHashFromStringFast(@_);
}

sub getVarStringFromHash
{
  return $APP->getVarStringFromHash(@_);
}

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

	my %vars;
	return \%vars unless ($$NODE{vars});

	%vars = getVarHashFromStringFast($$NODE{vars});
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

	getRef($NODE);

	unless (exists $$NODE{vars}) {
		warn ("setVars:\t'vars' field does not exist for node ".getId($NODE)."
		perhaps it doesn't join on the settings table?\n");
	}

	my $newVarsStr = getVarStringFromHash($varsref);
	return unless ($newVarsStr ne $$NODE{vars}); #we don't need to update...

	# Create a list of the vars-as-loaded
	my %originalVars = getVarHashFromStringFast($$NODE{vars});

	# Record just the modified vars
	my %modifiedVars = ();
	my @allVarNames = (keys %originalVars, keys %$varsref);
	foreach my $newVar (@allVarNames) {
		$modifiedVars{$newVar} = $$varsref{$newVar}
			if defined($$varsref{$newVar}) and $$varsref{$newVar} ne $originalVars{$newVar};
	}

	# Now lock the node's row in the DB, read its vars as they are now,
	#  poke in the modified vars, and then finally write it down
	# This way we avoid race conditions with vars being updated in multiple
	#  ways at once.  (No more infinite C!s.  q.q)
	my $updateSub = sub {
		my $currentVarString =
			$DB->sqlSelect('vars', 'setting', "setting_id = $$NODE{node_id}");
		my %currentVars = getVarHashFromStringFast($currentVarString);
		map { $currentVars{$_} = $modifiedVars{$_}; } keys %modifiedVars;
		map { delete $currentVars{$_} if !defined $$varsref{$_}; } keys %currentVars;
		$$NODE{vars} = getVarStringFromHash(\%currentVars);
		my $superuser = -1;
		$DB->updateNode($NODE, $superuser, 1);
	};

	transactionWrap($updateSub);
	if(UNIVERSAL::can('Everything::HTML','processVarsSet'))
	{
		Everything::HTML::processVarsSet($NODE);
	}
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
#		if no link was made, undef
#               if link was made or reinforced; array of source node ID and target node ID
#
sub updateLinks
{
	my ($TONODE, $FROMNODE, $type, $user_id) = @_;
	getRef $type;
	my $isSoftlink = 1
		if $type == 0 || (UNIVERSAL::isa($type,'HASH') && $$type{title} eq 'guest user link');

	return undef if getId($TONODE) == getId($FROMNODE) and $isSoftlink;
	getRef $TONODE;
	getRef $FROMNODE;
	
	return undef unless $TONODE && $FROMNODE;
	return undef unless ($$TONODE{type}{title} eq 'e2node' and $$FROMNODE{type}{title} eq 'e2node') or !$isSoftlink;
	return undef if $APP->isSpider();

	$type ||= 0;
	$type = getId $type;
	my $to_id = getId $TONODE;
	my $from_id = getId $FROMNODE;

	return undef if $to_id == $from_id;

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

	if ($user_id) {
		$DB->sqlInsert("softlink_creation"
			, {
				'from_node' => $from_id
				, 'to_node' => $to_id
				, 'creater_user_id' => $user_id
			}
		);
	}

	return ($from_id, $to_id);
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
	my ($NODE, $USER) = @_;
	my $id = $$NODE{node_id};

	return if $APP->isSpider();
	my $author_restrict = "AND author_user != $$USER{node_id}";
	$DB->sqlUpdate('hits', { -hits => 'hits+1' }, "node_id=$id");

	#Shift this work some to the webhead
	if($$NODE{author_user} != $$USER{node_id})
	{
		$DB->sqlUpdate('node', { -hits => 'hits+1' }, "node_id=$id");
	}

	if ($$NODE{type}{title} eq 'e2node' && $$NODE{group}) {
		my $groupList = '(';
		$groupList .= join ', ', @{$$NODE{group}};
		$groupList .= ')';
		$DB->sqlUpdate('node', { -hits => 'hits+1' },
			"node_id IN $groupList $author_restrict");
	}
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

	if($Everything::CONF->{maintenance_mode})
	{
		exit;
	}

	$DB = new Everything::NodeBase($db, $staticNodetypes, $memcache);
	$DB->closeTransaction();
	$APP = new Everything::Application($DB, $CONF);
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

sub commonLogLine
{
	my ($line) = @_;
	chomp $line;
	my $cmd = $0;
	$cmd =~ s/.*\/(.*)/$1/g;
	return "[".localtime()."][$$][$cmd] $line\n";
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
	my @callStack;
	my $neglect = shift;
	$neglect = 2 if not defined $neglect;

	my ($package, $file, $line, $subname, $hashargs);
	my $i = 0;

	while(($package, $file, $line, $subname, $hashargs) = caller($i++))
	{
		my $codeText = "";

		if ($subname eq "Everything::HTML::htmlcode"
				|| $subname eq "Everything::HTML::evalCode"
				) {
			my @calledArgs = caller_args($i - 1);
			$codeText = ":" . $calledArgs[0] if (scalar @calledArgs);
		}
		# We unshift it so that we can use "pop" to get them in the
		# desired order.
		unshift @callStack, "$file:$line:$subname$codeText";
	}

	# Get rid of this function and other callers that are part of the reporting.
	# We don't need to see "getCallStack" in the stack.
	while ($neglect--) { pop @callStack; }

	return @callStack;
}
#############################################################################
# end of package
#############################################################################

1;
