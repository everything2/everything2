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
use Mason;
use Everything::NodeBase;
use Everything::HTMLRouter;
use Everything::Application;
use Everything::Configuration;
use Everything::PluginFactory;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $CONF $FACTORY $MASON $ROUTER);
	@ISA=qw(Exporter);
	@EXPORT=qw(
              $APP
              $DB
	      $FACTORY
              $MASON
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
              printErr
              printLog

              commonLogLine
            );

	$CONF = Everything::Configuration->new("/etc/everything/everything.conf.json"); 
	$MASON = Mason->new(allow_globals => [qw($REQUEST)], data_dir => "/var/mason", comp_root => "/var/everything/templates");
	$ROUTER = Everything::HTMLRouter->new();

	foreach my $plugin ("API","Node","DataStash", "Controller")
	{
		$FACTORY->{lc($plugin)} = Everything::PluginFactory->new("Everything::$plugin");
		die $FACTORY->{lc($plugin)}->error_string if $FACTORY->{lc($plugin)}->error_string;
	}

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




sub printLog
{
  return $APP->printLog(@_);
}

sub devLog
{
  return $APP->devLog(@_);
}

sub getELogName
{
  return $APP->getELogName(@_);
}

sub getVars
{
  return $APP->getVars(@_);
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
			if defined($$varsref{$newVar}) and (!defined($originalVars{$newVar}) || $$varsref{$newVar} ne $originalVars{$newVar});
	}

	# Now lock the node's row in the DB, read its vars as they are now,
	#  poke in the modified vars, and then finally write it down
	# This way we avoid race conditions with vars being updated in multiple
	#  ways at once.  (No more infinite C!s.  q.q)
	my $updateSub = sub {
		my $currentVarString =
			$DB->sqlSelect('vars', 'setting', "setting_id = $$NODE{node_id}") || "";
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
sub initEverything
{
	if($Everything::CONF->maintenance_mode)
	{
		exit;
	}

	$DB ||= new Everything::NodeBase();
	$DB->{cache}->clearSessionCache();
	$DB->closeTransaction();
	$APP ||= new Everything::Application($DB, $CONF);
}

sub commonLogLine
{
  return $APP->commonLogLine(@_);
}

sub dumpCallStack
{
  return $APP->dumpCallStack(@_);
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
# end of package
#############################################################################

1;
