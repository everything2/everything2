package Everything::NodeBase;

#############################################################################
#	Everything::NodeBase
#		Wrapper for the Everything database and cache.  
#
#	Copyright 1999 Everything Development Inc.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;
use DBI;
use Everything;
use Everything::Application;
use Everything::NodeCache;
use Everything::Delegation::maintenance;
use Test::Deep::NoTest;
use JSON;
use Try::Tiny;

## no critic (ProhibitAutomaticExportation,RequireUseWarnings)

sub BEGIN
{
	use Exporter ();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		getCache
		getDatabaseHandle
		getAllTypes
		getNodetypeTables

		sqlDelete
		sqlInsert
		sqlUpdate
		sqlSelect
		sqlSelectMany
		sqlSelectHashref

		getFields
		getFieldsHash

		tableExists
		createNodeTable
		dropNodeTable
		addFieldToTable
		dropFieldFromTable

		getNodeParam
		getNodeParams
		setNodeParam
		deleteNodeParam
		getNodesWithParam

		quote
		genWhereString

		closeTransaction
		);
}

use vars qw($EDS);

#############################################################################
#	Sub
#		new
#
#	Purpose
#		Constructor for is module
#
#	Parameters
#		$dbname - the database name to connect to
#		$staticNodetypes - a performance enhancement.  If the nodetypes in
#			your system are fairly constant (you are not changing their
#			permissions dynmically or not manually changing them often) set
#			this to 1.  By turning this on we will derive the nodetypes
#			once and thus save that work each time we get a nodetype.  The
#			downside to this is that if you change a nodetype, you will need
#			to restart your web server for the change to take. 
#
#	Returns
#		A new NodeBase object
#
sub new
{
	my ($className) = @_;
	my $this = {};

	bless $this, $className;

    my $dbname = $Everything::CONF->database;
	# A connection to this database does not exist.  Create one.
	my ($user,$pass, $dbserv, $dbport) = ($Everything::CONF->everyuser, $Everything::CONF->everypass, $Everything::CONF->everything_dbserv, $Everything::CONF->everything_dbport);
	my $dbh_props = {
		AutoCommit => 1,
		mysql_enable_utf8mb4 => 1,
		mysql_auto_reconnect => 1,  # Auto-reconnect on connection loss
		PrintError => 1,            # Log errors
	};

	if($Everything::CONF->environment eq 'development')
	{
		$dbh_props->{RaiseError} = 1;
	}

	my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$dbserv;port=$dbport;mysql_ssl=1;mysql_get_server_pubkey=1", $user, $pass, $dbh_props);
	$this->{dbh} = $dbh;

	$this->{cache} = new Everything::NodeCache($this);
	$this->{dbname} = $dbname;
	$this->{staticNodetypes} = $Everything::CONF->static_nodetypes;

	$this->{cache}->clearSessionCache;

	return $this;
}


#############################################################################
#	Sub
#		getDatabaseHandle
#
#	Purpose
#		This returns the DBI connection to the database.  This can be used
#		to do raw database queries.  Unless you are doing something very
#		specific, you shouldn't need to access this.
#
#	Returns
#		The DBI database connection for this NodeBase.
#
sub getDatabaseHandle
{
	my ($this) = @_;

	return $this->{dbh};
}


#############################################################################
#	Sub
#		getCache
#
#	Purpose
#		This returns the NodeCache object that we are using to cache
#		nodes.  In general, you should never need to access the cache
#		directly.  This is more for maintenance type stuff (you want to
#		check the cache size, etc).
#
#	Returns
#		A reference to the NodeCache object
#
sub getCache
{
	my ($this) = @_;

	return $this->{cache};
}


#############################################################################
#	Sub
#		executeQuery
#
#	Purpose
#		Runs the given query string doing automatic logging as desired
#
#	Returns
#		The return value of the "do" function.
#
sub executeQuery
{
	my ($this, $query) = @_;

	my $result = $this->{dbh}->do($query);
	return $result;
}

#############################################################################
#	Sub
#		sqlDelete
#
#	Purpose
#		Quickie wrapper for deleting a row from a specified table.
#
#	Parameters
#		from - the sql table to delete the row from
#		where - what the sql query should match when deleting.
#
#	Returns
#		0 (false) if the sql command fails, 1 (true) if successful.
#
sub sqlDelete
{
	my ($this, $from, $where) = @_;

	$where or return;

	my $sql = "DELETE LOW_PRIORITY FROM $from WHERE $where";
	return $this->executeQuery($sql);
}


#############################################################################
#	Sub
#		sqlSelect
#
#	Purpose
#		Select specific fields from a single record.  If you need multiple
#		records, use sqlSelectMany.
#
#	Parameters
#		select - what colums to return from the select (ie "*")
#		from - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		An array of values from the specified fields in $select.  If
#		there is only one field, the return will be that value, not an
#		array.  Undef if no matches in the sql select.
#
sub sqlSelect
{
	my($this, $select, $from, $where, $other) = @_;
	my $cursor = $this->sqlSelectMany($select, $from, $where, $other);
	my @result;
	
	return if(not defined $cursor);

	@result = $cursor->fetchrow();
	$cursor->finish();
	
	return $result[0] if(scalar @result == 1);
	return @result;
}


#############################################################################
#	Sub
#		sqlSelectMany
#
#	Purpose
#		A general wrapper function for a standard SQL select command.
#		This returns the DBI cursor.
#
#	Parameters
#		select - what colums to return from the select (ie "*")
#		from - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		The sql cursor of the select.  Call fetchrow() on it to get
#		the selected rows.  undef if error.
#
sub sqlSelectMany
{
	my($this, $select, $from, $where, $other) = @_;

	my $sql="SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $cursor = $this->{dbh}->prepare($sql);
	my $result = $cursor->execute();
	
	return $cursor if($result);
	return;
}


#############################################################################
#	Sub
#		sqlSelectHashref
#
#	Purpose
#		Grab one row from a table and return it as a hash.  This just grabs
#		the first row from the select and returns it as a hash.  If you
#		want more than the first row, call sqlSelectMany and retrieve them
#		yourself.  This is basically a quickie for getting a single row.
#		
#	Parameters
#		select - what colums to return from the select (ie "*")
#		from - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		A hashref to the row that matches the query.  undef if no match.
#	
sub sqlSelectHashref
{
	my ($this, $select, $from, $where, $other) = @_;
	my $cursor = $this->sqlSelectMany($select, $from, $where, $other);
	my $hash;
	
	if(defined $cursor)
	{
		$hash = $cursor->fetchrow_hashref();
		$cursor->finish();
	}

	return $hash;
}


#############################################################################
#	Sub
#		sqlUpdate
#
#	Purpose
#		Wrapper for sql update command.
#
#	Parameters
#		table - the sql table to udpate
#		data - a hash reference that contains the fields and their values
#			that will be changed.
#		where - the string that contains the constraints as to which rows
#			will be updated.
#
#	Returns
#		Number of rows affected (true if something happened, false if
#		nothing was changed).
#
sub sqlUpdate
{
	my($this, $table, $data, $where) = @_;
	my $sql = "UPDATE $table SET";

	return unless keys %$data;

	foreach (keys %$data)
	{
		if (/^-/)
		{
			# If the parameter name starts with a '-', we need to treat
			# the value as a literal value (don't quote it).
			s/^-//;
			$sql .= "\n  $_" . ' = ' . $$data{'-' . $_} . ',';
		}
		else
		{
			# We need to quote the value
			$sql .= "\n  $_" . ' = ' . $this->{dbh}->quote($$data{$_}) . ',';
		}
	}

	chop($sql);

	$sql .= "\nWHERE $where\n" if $where;

	my $result = $this->executeQuery($sql);
	return $result if($result);
	Everything::printErr("sqlUpdate failed:\n $sql\n");
        return 0;
}


#############################################################################
#	Sub
#		sqlInsert
#
#	Purpose
#		Wrapper for the sql insert command.
#
#	Parameters
#		table - string name of the sql table to add the new row
#		data - a hash reference that contains the fieldname => value
#			pairs.  If the fieldname starts with a '-', the value is
#			treated as a literal value and thus not quoted/escaped.
#
#	Returns
#		true if successful, false otherwise.
#
sub sqlInsert
{
	my ($this, $table, $data, $updateData) = @_;
	my ($names, $values, $updateSql) = ('', '', '');

	foreach (keys %$data)
	{
		if (/^-/)
		{
			$values .= "\n  " . $$data{$_} . ','; s/^-//;
		}
		else
		{
			$values .= "\n  " . $this->{dbh}->quote($$data{$_}) . ',';
		}

		$names .= "$_,";
	}

	chop($names);
	chop($values);

	if ($updateData) {
		$updateSql = "\nON DUPLICATE KEY UPDATE";
		foreach my $updateName (keys %$updateData)
		{
			my $updateValue = $$updateData{$updateName};
			if ($updateName =~ m/^-/)
			{
				$updateName =~ s/^-//;
			}
			else
			{
				$updateValue = $this->{dbh}->quote($updateValue);
			}
			$updateSql .= "\n  $updateName = $updateValue,";
		}
		chop $updateSql;
	}

	my $sql = "INSERT INTO $table ($names) VALUES($values)$updateSql\n";
	my $result = $this->executeQuery($sql);
	return $result if($result);

	Everything::printErr("sqlInsert failed:\n $sql");
	return 0;
}


#############################################################################
#	Sub
#		getNode
#
#	Purpose
#		Get a node by title and type.  This only returns the first match. 
#		To get all matches, use	getNodeWhere which returns an array.
#
#	Parameters
#		$title - the title or numeric ID of the node
#		$TYPE - the nodetype hash of the node, or the title of the type.
#
#	Returns
#		A node hashref if a node is found.  undef otherwise.
#
sub getNode
{
	my ($this, $title, $TYPE, $selectop) = @_;
	my $NODE;
	return unless $title;

	if (not $TYPE and $title =~ /^\d+$/) {
		return $this->getNodeById($title, $selectop);
	}

	if(defined $TYPE)
	{
		$TYPE = $this->getType($TYPE) unless(UNIVERSAL::isa($TYPE,'HASH'));
	}

	$selectop ||= '';

	if($selectop ne 'nocache')
	{
		$NODE = $this->{cache}->getCachedNodeByName($title, $$TYPE{title});
		return $NODE if (defined $NODE);
	}

	if ($selectop eq 'light') {
		$NODE = $this->sqlSelectHashref('*', 'node', 'title=' . $this->{dbh}->quote($title) . ' and type_nodetype=' . $$TYPE{node_id});
		return $NODE;
	}


	# If it looks like there's a double encoded character, try looking up both this title and the title
	#  with an additional decode
	if ($title !~ /%/) {
		($NODE) = $this->getNodeWhere({ 'title' => $title }, $TYPE);
	} else {
		($NODE) = $this->getNodeWhere({ 'title' => [ $title, CGI::unescape($title) ] }, $TYPE);
	}

	if(defined $NODE and $selectop ne 'nocache')
	{
		my $perm = 0;
		my $type_title = $$NODE{type}{title};
		$perm = 1 if exists $Everything::CONF->static_cache->{$type_title}
		          || exists $Everything::CONF->permanent_cache->{$type_title};
		$this->{cache}->cacheNode($NODE, $perm);
	}

	return $NODE;
}


#############################################################################
#	Sub
#		getNodeById
#
#	Purpose
#		This takes a node id or node hash reference (all we need is the id)
#		and loads the node into a hash by attaching the other table data.
#
#		If the node is a group node, the group members will be added to
#		the "group" key in the hash.
#
#	Parameters
#		N - either an integer node Id, or a reference to a node hash.
#		selectop - either "force", "light", or "".  If set to "force", this
#			will do the work even if the node is cached.  If set to "light"
#			it just attaches the nodetype hash to the node.  If "" or null,
#			it resolves nodegroup stuff and attaches the extra table data.
#
#	Returns
#		A node hash reference.  False if failure.
#
sub getNodeById
{
	my ($this, $N, $selectop) = @_;
	my $groupTable;
	my $NODETYPE;
	my $NODE;
	my $table;
	my $cachedNode;
	return unless $N;
	$selectop ||= '';
	return -1 if $N == -1;
	$N = $this->getId($N);
	$N = int($N);
	return unless $N;

	if($selectop ne 'nocache')
	{
		# See if we have this node cached already
		$cachedNode = $this->{cache}->getCachedNodeById($N);
		return $cachedNode unless ($selectop eq 'force' or not $cachedNode);
	}

	$NODE = $this->sqlSelectHashref('*', 'node', "node_id=$N");
	return if(not defined $NODE);

	$NODETYPE = $this->getType($$NODE{type_nodetype});
	if (not defined $NODETYPE or $NODETYPE == -1) {
		Everything::printLog(
			"Node $$NODE{title} (#$$NODE{node_id}) has a bad nodetype #$$NODE{type_nodetype}."
			. '  This can\'t end well.'
		);
		return if not defined $NODETYPE;
	}

	# Wire up the node's nodetype
	$$NODE{type} = $NODETYPE;

	if ($selectop eq 'light')
	{
		# Note that we do not cache the node.  We don't want to cache a
		# node that does not have its table data (its not complete).
		return $NODE;
	}

	# Get the rest of the info for this node
	$this->constructNode($NODE);

	# Fill out the group in the node, if its a group node.
	$this->loadGroupNodeIDs($NODE);

	# Store this node in the cache.

	if($selectop ne 'nocache')
	{
		my $perm = 0;
		my $type_title = $$NODE{type}{title};
		$perm = 1 if exists $Everything::CONF->static_cache->{$type_title}
		          || exists $Everything::CONF->permanent_cache->{$type_title};

		$this->{cache}->cacheNode($NODE, $perm);
	}

	return $NODE;
}


#############################################################################
#	Sub
#		loadGroupNodeIDs
#
#	Purpose
#		A group nodetype has zero or more nodes in its group.  This
#		will get the node ids from the group, and store them in the
#		'group' key of the node hash.
#
#	Parameters
#		$NODE - the group node to load node IDs for.  If the given
#			node is not a group node, this will do nothing.
#
sub loadGroupNodeIDs
{
	my ($this, $NODE, $hash, $recursive) = @_;
	my $groupTable;

	# If this node is a group node, add the nodes in its group to its array.
	if ($groupTable = $this->isGroup($$NODE{type}))
	{
		my $cursor;
		my $nid;

		if(not defined $$NODE{group})
		{
			$cursor = $this->sqlSelectMany('node_id', $groupTable,
				$groupTable . "_id=$$NODE{node_id}", 'ORDER BY orderby');
		
			while($nid = $cursor->fetchrow)
			{
				push @{ $$NODE{group} }, $nid;
			}

			$cursor->finish();
		}
	}

	return;
}


#############################################################################
#	Sub
#		getNodeWhere
#
#	Purpose
#		Get a list of NODE hashes.  This constructs a complete node.
#
#	Parameters
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#
#	Returns
#		An array of integer node id's that match the query.
#
sub getNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby) = @_;
	my $NODE;
	my @nodelist;
	my $cursor;

	$cursor = $this->getNodeCursor($WHERE, $TYPE, $orderby);

	if(defined $cursor)
	{
		while($NODE = $cursor->fetchrow_hashref)
		{
			# NOTE: This duplicates some stuff from getNodeById().  The
			# reason that we don't call getNodeById here is pure
			# performance.  We already have the entire hash.  We just
			# need the type and any group info.  Calling getNodeById
			# would result in two extra sql queries that we don't need.

			# Attach the type to the node
			$$NODE{type} = $this->getType($$NODE{type_nodetype});

			# Fill out the group, if its a group node.
			$this->loadGroupNodeIDs($NODE);

			push @nodelist, $NODE;
		}

		$cursor->finish();
	}

	return @nodelist;
}


#############################################################################
#	Sub
#		selectNodeWhere
#
#	Purpose
#		Retrieves node id's that match the given query.
#
#	Parameters
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#			Note that if this is turned on you will not get "complete" nodes,
#			just the data from the "node" table.
#
#	Returns
#		A refernce to an array that contains the node ids that match.
#		Undef if no matches.
#
sub selectNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby, $nodeTableOnly) = @_;
	my $cursor;
	my $select;
	my @nodelist;
	my $node_id;

	$cursor = $this->getNodeCursor($WHERE, $TYPE, $orderby, $nodeTableOnly);

	if((defined $cursor) && ($cursor->execute()))
	{
		while (($node_id) = $cursor->fetchrow) 
		{
			push @nodelist, $node_id; 
		}
		
		$cursor->finish();
	}

	return unless(@nodelist);
	
	return \@nodelist;
}


#############################################################################
#	Sub
#		getNodeCursor
#
#	Purpose
#		This returns the sql cursor for node matches.  Users of this object
#		can call this directly for specific searches, but the more general
#		functions selectNodeWhere() and getNodeWhere() should be used for
#		most cases.
#
#	Parameters
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#			Note that if this is turned on you will not get "complete" nodes,
#			just the data from the "node" table.
#
#	Returns
#		The sql cursor from the "select".  undef if their was an error
#		in the search or no matches.  The caller is responsible for calling
#		finish() on the cursor.
#		
sub getNodeCursor
{
	my ($this, $WHERE, $TYPE, $orderby, $nodeTableOnly) = @_;
	my $cursor;
	my $select;

	$nodeTableOnly ||= 0;

	$TYPE = $this->getType($TYPE) if((defined $TYPE) && (!UNIVERSAL::isa($TYPE,'HASH')));

	my $wherestr = $this->genWhereString($WHERE, $TYPE, $orderby);

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.
	$select = 'SELECT * FROM node';

	# Now we need to join on the appropriate tables.
	if((! $nodeTableOnly) && (defined $TYPE) && (ref $$TYPE{tableArray}))
	{
		my $tableArray = $$TYPE{tableArray};

		foreach my $table (@$tableArray)
		{
			$select .= " LEFT OUTER JOIN $table ON node_id=" . $table . '_id';
		}
	}

	$select .= ' WHERE ' . $wherestr if($wherestr);

	if ($select eq 'SELECT * FROM node')
	{
		Everything::HTML::htmlFormatErr($select, 'getNodeCursor() tried to evaluate a stupid query', '');
		return;
	}

	#$select .= " FOR UPDATE" if $this->{dbh}->{AutoCommit} == 0;

	$cursor = $this->{dbh}->prepare($select);
	my $result = $cursor->execute();

	return $cursor if($result);
	return;
}


#############################################################################
#	Sub
#		constructNode
#
#	Purpose
#		Given a hash that contains a row of data from the 'node' table,
#		get its type and "join" on the appropriate tables.  This function
#		is designed to work in conjuction with simple queries that only
#		search the node table, but then want a complete node.  (ie do a
#		search on the node table, find something, now we want the complete
#		node).
#
#	Parameters
#		$NODE - the incomplete node that should be filled out.
sub constructNode
{
	my ($this, $NODE) = @_;
	my $TYPE = $this->getType($$NODE{type_nodetype});
	my $cursor;
	my $NODEDATA;

	return 0 unless((defined $TYPE) && (ref $$TYPE{tableArray}));

	$cursor = $this->getNodeCursor({-node_id => $$NODE{node_id}}, $TYPE);

	return 0 if(not defined $cursor);

	$NODEDATA = $cursor->fetchrow_hashref();
	$cursor->finish();

	@$NODE{keys %$NODEDATA} = values %$NODEDATA;

	# Make sure each field is at least defined to be nothing.
	foreach (keys %$NODE)
	{
		$$NODE{$_} = '' unless defined ($$NODE{$_});
	}

	return 1;
}

#############################################################################
#	Sub
#		updateLockedNode
#
#	Purpose
#		Get a fresh copy of a node from the database, locking it
#		from updates, change some values, then update the node.
#
#	Parameters
#		$NODE - the node to update
#		$USER - the user attempting to update this node (used for
#			authorization)
#		$CODE - a coderef to the actions to perform on the $NODE
#			where the node as read from the databsae is passed in
#			as an argument
#
#	Returns
#		True if successful, false otherwise.
#
sub updateLockedNode
{
	my ($this, $NODELIST, $USER, $CODE) = @_;
	my @freshNodes;

	if (ref $NODELIST ne 'ARRAY') {
		$NODELIST = [ $NODELIST ];
	}

	# We don't use getId() here because getId() won't do lists
	my @node_id_list =
		map { UNIVERSAL::isa($_, 'HASH') ? int($_{node_id}) : int $_ } @$NODELIST;

	my $updateSub = sub {
		# Grab a fresh copy of each node, locking the nodes' DB rows.
		@freshNodes = map { $this->getNodeById($_, 'force') } @node_id_list;
		# Only proceed if we can update all locked nodes
		return if grep { !$this->canUpdateNode($USER, $_) } @freshNodes;

		&$CODE(@freshNodes);
		map { $this->updateNode($_, $USER) } @freshNodes;
		return 1;
	};

	my $success = $this->transactionWrap($updateSub);
	return 1 if $success;
	my $errorNodes =
			join(', ', map { $_->{title} . '(' . $_->{node_id} . ')' } @freshNodes);
	Everything::printLog(
		"Attempt to do a locked update on $errorNodes failed!\n$@"
	);
	return 0;

}

#############################################################################
#	Sub
#		transactionWrap
#
#	Purpose
#		Executes some code wrapped in a SQL transaction, automatically
#		retrying on failures.
#
#	Parameters
#		$CODE - coderef to the code to run
#		$commitTries (optional) - number of times to try to run the code
#			before giving up
#
#	Returns
#		True if successful, false otherwise ($@ will contain the error)
#
sub transactionWrap
{
	my ($this, $CODE, $commitTries) = @_;
	my ($committed, $commitTriesLeft) = (0, 5);
	# By saving AutoCommit, calls to this funciton can be nested, although
	#  that could mean a long-lived transaction.  Abuse with caution.
	my $savedAutoCommit = $this->{dbh}->{AutoCommit};
	my $savedRaiseError = $this->{dbh}->{RaiseError};
	my $accumulatedErrors = '';

	$this->{dbh}->{AutoCommit} = 0;
	$this->{dbh}->{RaiseError} = 1;
	$commitTriesLeft = $commitTries if ($commitTries && $commitTries > 0);

	while (!$committed && $commitTriesLeft) {

		$commitTriesLeft -= 1;

		my $commitfailure = 0;

		try {
			eval {
				&$CODE;
				$this->{dbh}->commit;
			} or do {
				$commitfailure = 1;
				$accumulatedErrors .= "Error $commitTriesLeft: " . $@ . "\n";
			}
		} catch {
			$commitfailure = 1;
			$accumulatedErrors .= "Error $commitTriesLeft: $_\n";
		};

		if($commitfailure)
		{
			$this->{dbh}->rollback();
		}
	}

	$this->{dbh}->{RaiseError} = $savedRaiseError;
	$this->{dbh}->{AutoCommit} = $savedAutoCommit;
	local $@ = $accumulatedErrors;
	return $committed;
}


#############################################################################
#	Sub
#		closeTransaction
#
#	Purpose
#		Should generally be a nop, but is called to insure transactions are
#		closed so they don't propogate past a pageload
#
#	Returns
#		Nothing
#
sub closeTransaction
{
	my ($this) = @_;

	# Prevent AutoCommit mistakes from propgating, creating weird superlong transactions
	if (!$this->{dbh}->{AutoCommit}) {
		Everything::printLog('AutoCommit was left off after the last page served.');
		$this->{dbh}->{AutoCommit} = 1;
	}

	return;
}

#############################################################################
#	Sub
#		updateNode
#
#	Purpose
#		Update the given node in the database.
#
#	Parameters
#		$NODE - the node to update
#		$USER - the user attempting to update this node (used for
#			authorization)
#		$light - used by setVars(), don't update document table
#
#	Returns
#		True if successful, false otherwise.
#
sub updateNode
{
	my ($this, $NODE, $USER, $light, $skip_maintenance) = @_;
	my %VALUES;
	my $tableArray;

	$this->getRef($NODE);
	return 0 unless ($this->canUpdateNode($USER, $NODE)); 

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	my $ORIGINAL_NODE = $this->getNodeById($NODE->{node_id},'nocache');

	$tableArray = $$NODE{type}{tableArray};

	# The node table is assumed, so its not in the "joined" table array.
	# However, for this update, we need to add it.
	push @$tableArray, 'node';

	my $fieldHash = $this->getFieldsHash($tableArray);
	my %tableList = (); # So we only update tables as required


	foreach my $table (keys %$fieldHash)
	{
		next if $light and $table eq 'document';

		foreach my $ordinal (keys %{$fieldHash->{$table}})
		{

			my $field = $fieldHash->{$table}->{$ordinal}->{COLUMN_NAME};

			# we don't want to chance mucking with the primary key
			next if $field eq $table . '_id';
			# don't write a value if we haven't changed it since we read the node
			if(UNIVERSAL::isa($ORIGINAL_NODE,'HASH') and eq_deeply($ORIGINAL_NODE->{$field}, $NODE->{$field}))
			{
				next;
			}

			# don't allow prohibited duplicate titles, but do allow case changes
			if ($field eq 'title' && $$NODE{type}{restrictdupes}
				&& $this->sqlSelect('node_id', 'node',
					'title='.$this->quote($$NODE{$field})
					." AND type_nodetype=$$NODE{type_nodetype} AND node_id!=$$NODE{node_id}"))
			{
				$NODE->{title} = $ORIGINAL_NODE->{title};
				next;
			}

			if (exists $$NODE{$field})
			{ 
				my $qualified_column =
				  $this->{dbh}->quote_identifier(undef, undef, $table, $field);
				$VALUES{$qualified_column} = $$NODE{$field};
				$tableList{$table} = 1;
			}

		}

	}

	# We are done with tableArray.  Remove the "node" table that we put on
	pop @$tableArray;

	# If no fields have been updated, don't update node
	if (scalar keys %VALUES > 0) {

		my $tableListStr = join(', ', keys %tableList);
		my $updateList =
			join(
				"\n\t\t,"
				, map {$_ . ' = ' . $this->{dbh}->quote($VALUES{$_}) }
					keys %VALUES
			);
		my $whereStr =
			join("\n\t\tAND "
				, map {$_ . '_id = ' . $$NODE{node_id} } keys %tableList
			);
		my $sqlString = qq|UPDATE $tableListStr SET $updateList WHERE $whereStr|;

		$this->executeQuery($sqlString);

		# Cache this node since it has been updated.  This way the cached
		# version will be the same as the node in the db.
		$this->{cache}->incrementGlobalVersion($NODE);
		$this->{cache}->cacheNode($NODE) if(defined $this->{cache});

	}
	$ORIGINAL_NODE = undef;

	# This node has just been updated.  Do any maintenance if needed.
	$this->nodeMaintenance($NODE, 'update') unless $skip_maintenance;

	return 1;
}

############################################################################
#	sub
#		replaceNode
#
#	purpose
#		given insertNode information, test whether or not the node is there
#		if it is, update it, otherwise insert the node as new
#
sub replaceNode {
	my ($this, $title, $TYPE, $USER, $NODEDATA, $skip_maintenance) = @_;

	if (my $N = $this->getNode($title, $TYPE)) {
		if ($this->canUpdateNode($USER,$N)) {
			@$N{keys %$NODEDATA} = values %$NODEDATA if $NODEDATA;
			$this->updateNode($N, $USER, undef, $skip_maintenance);
		}
	} else {
		$this->insertNode($title, $TYPE, $USER, $NODEDATA, $skip_maintenance);
	}

	return;
}


#############################################################################
#	Sub
#		insertNode
#
#	Purpose
#		Insert a new node into the tables.
#
#	Parameters
#		title - the string title of the node
#		TYPE - the hash of the type that we want to insert
#		USER - the user trying to do this (used for authorization)
#		DATA - the fields/values of the node to set.
#
#	Returns
#		The id of the node inserted, or false if error (sql problem, node
#		already exists).
#
sub insertNode
{
	my ($this, $title, $TYPE, $USER, $NODEDATA, $skip_maintenance) = @_;
	my $tableArray;
	my $NODE;


	$TYPE = $this->getType($TYPE) unless (ref $TYPE);

	unless ($this->canCreateNode($USER, $TYPE))
	{
		Everything::printErr(
			"$$USER{title} not allowed to create this type of node!");
		return 0;
	}

	if ($$TYPE{restrictdupes})
	{
		# Check to see if we already have a node of this title.
		my $DUPELIST = $this->sqlSelect('*', 'node', 'title=' .
			$this->quote($title) . ' && type_nodetype=' . $$TYPE{node_id});

		if ($DUPELIST)
		{
			# A node of this name already exists and restrict dupes is
			# on for this nodetype.  Don't do anything
			return 0;
		}
	}

	$this->sqlInsert('node', 
			{title => $title, 
			type_nodetype => $$TYPE{node_id}, 
			author_user => $this->getId($USER), 
			hits => 0,
			-createtime => 'now()'}); 



	# Get the id of the node that we just inserted.
	my ($node_id) = $this->sqlSelect('LAST_INSERT_ID()');


	#this is for the hits table
	$this->sqlInsert('hits', {node_id => $node_id, hits => 0}); 

	# Now go and insert the appropriate rows in the other tables that
	# make up this nodetype;
	$tableArray = $$TYPE{tableArray};
	foreach my $table (@$tableArray)
	{
		$this->sqlInsert($table, { $table . '_id' => $node_id });
	}

	$NODE = $this->getNodeById($node_id, 'force');

	my $app = Everything::Application->new($this, $Everything::CONF);
 	$app->insertSearchWord($title, $node_id);

	# This node has just been created.  Do any maintenance if needed.
	# We do this here before calling updateNode below to make sure that
	# the 'created' routines are executed before any 'update' routines.
	$this->nodeMaintenance($NODE, 'create') unless $skip_maintenance;

	if ($NODEDATA)
	{
		@$NODE{keys %$NODEDATA} = values %$NODEDATA;
		$this->updateNode($NODE, $USER, undef, $skip_maintenance); 
	}

	return $node_id;
}

#######################################################################
#   sub
#       tombstoneNode
#
#   purpose
#       save a soon-to-be-nuked node to the tomb table, so that
#       if we ever need to restore it, we can
#       take same params as nukeNode
#
sub tombstoneNode {
    my ($this, $NODE, $USER) = @_;

    my %N = %{ $NODE };  #create a copy of the node hash;
    my %data = %N;

    $N{killa_user} = $this->getId($USER);

    my @fields = $this->getFields('tomb');
    foreach (@fields) { delete $data{$_} if exists $data{$_} }
    foreach (keys %data) {
        delete $N{$_};
    }
    delete $data{type};

    use Data::Dumper;
    $N{data} = Data::Dumper->Dump([\%data]);
    $this->sqlInsert('tomb', \%N);
    return;
}


#############################################################################
#	Sub
#		nukeNode
#
#	Purpose
#		Given a node, delete it and all of its associated table data.
#		If it is a group node, this will also clean out all of its
#		entries in its group table.
#
#	Parameters
#		$NODE - the node in which we wish to delete
#		$USER - the user trying to do this (used for authorization)
#
#	Returns
#		True if successful, false otherwise.
#	
sub nukeNode
{
	my ($this, $NODE, $USER, $NOTOMB, $skip_maintenance) = @_;
	my $tableArray;
	my $result = 0;
	my $groupTable;

	$this->getRef($NODE, $USER);

	return unless ($this->canDeleteNode($USER, $NODE));

	$this->tombstoneNode($NODE, $USER) unless $NOTOMB;

	# This node is about to be deleted.  Do any maintenance if needed.
	$this->nodeMaintenance($NODE, 'delete') unless $skip_maintenance;

	# Delete this node from the cache that we keep.
	$this->{cache}->incrementGlobalVersion($NODE);
	$this->{cache}->removeNode($NODE);

	$tableArray = $$NODE{type}{tableArray};

	push @$tableArray, 'node';  # the node table is not in there.

	foreach my $table (@$tableArray)
	{
		my $sql = "DELETE FROM $table WHERE " . $table . "_id=$$NODE{node_id}";
		$result += $this->executeQuery($sql);
	}

	pop @$tableArray; # remove the implied "node" that we put on

	# Remove all links that go from or to this node that we are deleting
	$this->executeQuery("DELETE LOW_PRIORITY FROM links WHERE to_node=$$NODE{node_id}");

	$this->executeQuery("DELETE LOW_PRIORITY FROM links WHERE from_node=$$NODE{node_id}");

	# If this node is a group node, we will remove all of its members
	# from the group table.
	if($groupTable = $this->isGroup($$NODE{type}))
	{
		# Remove all group entries for this group node
		$this->executeQuery("DELETE FROM $groupTable WHERE $groupTable"."_id=$$NODE{node_id}");
	}

	$this->executeQuery("DELETE FROM nodegroup WHERE node_id=$$NODE{node_id}");
	my $app = Everything::Application->new($this, $Everything::CONF);
	$app->removeSearchWord($NODE);

	# This will be zero if nothing was deleted from the tables.
	return $result;
}


#############################################################################
#	Sub
#		resurrectNode
#
#	Purpose
#		Resurrect a deleted node from the tomb or heaven table.
#		This reverses the nukeNode operation by deserializing the node
#		data and reconstructing it in all appropriate tables.
#
#	Parameters
#		$node_id - the node_id to resurrect
#		$burialground - optional, 'tomb' or 'heaven' (defaults to 'tomb')
#
#	Returns
#		The resurrected node on success, undef on failure
#
sub resurrectNode
{
	my ($this, $node_id, $burialground) = @_;

	$burialground ||= 'tomb';

	# Check if node already exists - can't resurrect a living node
	my $existing = $this->getNodeById($node_id);
	return if $existing;

	# Retrieve the tombstone record
	my $tomb = $this->sqlSelectHashref('*', $burialground, 'node_id=' . $this->quote($node_id));
	return unless $tomb;
	return unless $tomb->{data};

	# Deserialize the node data using safe deserialization
	require Everything::Serialization;
	Everything::Serialization->import('safe_deserialize_dumper');

	my $nodeproto = safe_deserialize_dumper('my ' . $tomb->{data});
	return unless $nodeproto;
	return unless ref($nodeproto) eq 'HASH';

	# Get the tables for this node type
	my $typetables = $this->getNodetypeTables($tomb->{type_nodetype});
	return unless $typetables;

	push @$typetables, 'node';

	# Reconstruct the node in all tables
	foreach my $table (@$typetables)
	{
		my @fields = $this->getFieldsHash($table);
		my $insertref = {};

		foreach my $field_info (@fields)
		{
			my $field = $field_info->{Field};
			# Match original logic: try nodeproto first, then tomb, then 0
			# Use ||= to treat undef/0/"" as false and fall through
			$insertref->{$field} = $nodeproto->{$field};
			$insertref->{$field} ||= $tomb->{$field};
			$insertref->{$field} ||= 0;
		}

		# Primary key may not be in the data if new tables added since nuke
		$insertref->{"${table}_id"} = $node_id;

		# Clean out any existing data and insert fresh
		$this->sqlDelete($table, "${table}_id=" . $this->quote($node_id));
		$this->sqlInsert($table, $insertref);
	}

	pop @$typetables; # Remove the "node" table we added

	# Delete the tombstone now that resurrection is complete
	# This allows the node to be nuked again with a fresh tombstone if needed
	$this->sqlDelete($burialground, 'node_id=' . $this->quote($node_id));

	# Fetch and return the resurrected node (bypass cache since we just reconstructed it)
	my $resurrected = $this->getNodeById($node_id, 'nocache');

	return $resurrected;
}


#############################################################################
#	Sub
#		getType
#
#	Purpose
#		Get a nodetype.  This must be called to get a nodetype.  You
#		cannot retrieve a nodetype through selectNodeWhere, getNodeById,
#		etc.  Nodetypes are derived and inherit values from "parent"
#		nodetypes.  This takes care of the tricky part of getting the
#		nodetypes loaded and properly derives their values.
#
#	Returns
#		A hash ref to a nodetype node.  undef if not found
#
sub getType
{
	my ($this, $idOrName) = @_;
	my $TYPE;
	my $NODE;
	my $field;
	my $fromCache = 1;

	# We assume that the nodetypes join on the 'nodetype' table and the
	# nodetype 'nodetype' is always id #1.  If this changes, this will
	# break and we will need to change this stuff.

	# If they pass in a hash, just take the id.
	$idOrName = $$idOrName{node_id} if(UNIVERSAL::isa($idOrName,'HASH'));

	return if((not defined $idOrName) || ($idOrName eq ''));

	if($idOrName =~ /\D/) # Does it contain non-digits?
	{
		# It is a string name of the nodetype we are looking for.
		$TYPE = $this->{cache}->getCachedNodeByName($idOrName, 'nodetype');

		if(not defined $TYPE)
		{
			$TYPE = $this->sqlSelectHashref('*',
				'node left join nodetype on node_id=nodetype_id',
				'title=' . $this->quote($idOrName) . ' && type_nodetype=1');

			$fromCache = 0;
		}
	}
	elsif($idOrName > 0)
	{
		# Its an id
		$TYPE = $this->{cache}->getCachedNodeById($idOrName);

		if(not defined $TYPE)
		{
			$TYPE = $this->sqlSelectHashref('*',
				'node left join nodetype on node_id=nodetype_id',
				"node_id=$idOrName && type_nodetype=1");
			
			$fromCache = 0;
		}
	}
	else
	{
		# We only get here if the id is zero or negative
		return;
	}

	# If we did not find a matching nodetype, forget it.
	return unless(defined $TYPE);

	if(not exists $$TYPE{type})
	{
		# We need to assign the "type".
		if($$TYPE{node_id} == 1) {
			# This is the nodetype nodetype, it is its own type.
			$$TYPE{type} = $TYPE;
		}
		else
		{
			# Get the type and assign it.
			$$TYPE{type} = $this->getType($$TYPE{type_nodetype});
		}
	}
	
	if(not exists $$TYPE{resolvedInheritance})
	{
		$TYPE = $this->deriveType($TYPE);
		# If this didn't come from the cache, we need to cache it
		$this->{cache}->cacheNode($TYPE, 1) if((not $fromCache) && 
			(not $this->{staticNodetypes}));
		
		# If we have static nodetypes, we can do a performance enhancement
		# by caching the completed nodes.
		$this->{cache}->cacheNode($TYPE, 1) if($this->{staticNodetypes});
	}
	
	return $TYPE;
}


#############################################################################
#	Sub
#		getAllTypes
#
#	Purpose
#		This returns an array that contains all of the nodetypes in the
#		system.  Useful for knowing what nodetypes exist.
#
#	Parameters
#		None
#
#	Returns
#		An array of TYPE hashes of all the nodetypes in the system
#
sub getAllTypes
{
	my ($this) = @_;
	my $sql;
	my $cursor;
	my @allTypes = ();
	my $node_id;
	my $TYPE = $this->getType('nodetype');

	$sql = 'SELECT node_id FROM node WHERE type_nodetype = ' . $$TYPE{node_id};
	$cursor = $this->{dbh}->prepare($sql);
	if($cursor && $cursor->execute())
	{
		while( ($node_id) = $cursor->fetchrow() )
		{
			$TYPE = $this->getType($node_id);
			push @allTypes, $TYPE;
		}
		
		$cursor->finish();
	}

	return @allTypes;
}


#############################################################################
#   Sub
#       getFields
#
#   Purpose
#       Get the field names of a table.
#
#   Parameters
#       $table - the name of the table of which to get the field names
#
#   Returns
#       An array of field names
#
sub getFields
{
	my ($this, $table) = @_;

	return $this->getFieldsHash($table, 0);
}


#############################################################################
#   Sub
#       getFieldsHash
#
#   Purpose
#       Given a table name, returns a list of the fields or a hash.
#
#   Parameters
#       $table - the name of the table to get fields for
#       $getHash - set to 1 if you would also like the entire field hash
#           instead of just the field name. (set to 1 by default)
#
#   Returns
#       Array of field names, if getHash is 1, it will be an array of
#       hashrefs of the fields.
#
sub getFieldsHash
{
	my ($this, $table, $getHash) = @_;
	my $field;
	my @fields;
	my $value;

	$getHash = 1 if(not defined $getHash);
	$table ||= 'node';

	if (ref $table eq 'ARRAY') {

			my $paramList = ' (?' . (', ?' x (-1 + scalar @$table)) . ') ';
			my $sqlQuery = qq|
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME IN
		$paramList
		AND table_schema = ?|;

			return $this->{dbh}->selectall_hashref(
			  $sqlQuery
			  , [ 'TABLE_NAME', 'ORDINAL_POSITION' ]
			  , {}, (@$table, $this->{dbname})
			  );

	} else {

			my $cursor = $this->{dbh}->prepare_cached("SHOW COLUMNS FROM $table");

			$cursor->execute;
			while ($field = $cursor->fetchrow_hashref)
			{
				$value = ( ($getHash == 1) ? $field : $$field{Field});
				push @fields, $value;
			}

			$cursor->finish();

			return @fields;

	}
}


#############################################################################
#	Sub
#		tableExists
#
#	Purpose
#		Check to see if a table of the given name exists in this database.
#
#	Parameters
#		$tableName - the table to check for.
#
#	Returns
#		1 if it exists, 0 if not.
#
sub tableExists
{
	my ($this, $tableName) = @_;
	my $cursor = $this->{dbh}->prepare('SHOW TABLES');
	my $table;
	my $exists = 0;

	$cursor->execute();
	while((($table) = $cursor->fetchrow()) && (not $exists))
	{
		  $exists = 1 if($table eq $tableName);
	}

	$cursor->finish();

	return $exists;
}


#############################################################################
#	Sub
#		createNodeTable
#
#	Purpose
#		Create a new database table for a node, if it does not already
#		exist.  This creates a new table with one field for the id of
#		the node in the form of tablename_id.
#
#	Parameters
#		$tableName - the name of the table to create
#
#	Returns
#		1 if successful, 0 if failure, -1 if it already exists.
#
sub createNodeTable
{
	my ($this, $table) = @_;
	my $tableid = $table . '_id';
	my $result;

	return -1 if($this->tableExists($table));

	$result = $this->executeQuery("CREATE TABLE $table ($tableid int(11)" .
		" DEFAULT '0' NOT NULL, PRIMARY KEY($tableid))");

	return $result;
}


#############################################################################
#	Sub
#		dropNodeTable
#
#	Purpose
#		Drop (delete) a table from a the database.  Note!!! This is
#		perminent!  You will lose all data in that table.
#
#	Parameters
#		$table - the name of the table to drop.
#
#	Returns
#		1 if successful, 0 otherwise.
#
sub dropNodeTable
{
	my ($this, $table) = @_;
	
	# These are the tables that we don't want to drop.  Dropping one
	# of these, could cause the entire system to break.  If you really
	# want to drop one of these, do it from the command line.
	my @nodrop = (
		'container',
		'document',
		'htmlcode',
		'htmlpage',
		'image',
		'links',
		'maintenance',
		'node',
		'nodegroup',
		'nodelet',
		'nodetype',
		'note',
		'rating',
		'user',
		'useractionlog' );

	foreach (@nodrop)
	{
		if($_ eq $table)
		{
			Everything::printLog("WARNING! Attempted to drop core table $table!");
			return 0;
		}
	}
	
	return 0 unless($this->tableExists($table));

	Everything::printLog("Dropping table $table");
	return $this->executeQuery("DROP TABLE $table");
}


#############################################################################
#	Sub
#		addFieldToTable
#
#	Purpose
#		Add a new field to an existing database table.
#
#	Parameters
#		$table - the table to add the new field to.
#		$fieldname - the name of the field to add
#		$type - the type of the field (ie int(11), char(32), etc)
#		$primary - (optional) is this field a primary key?  Defaults to no.
#		$default - (optional) the default value of the field.
#
#	Returns
#		1 if successful, 0 if failure.
#
sub addFieldToTable
{
	my ($this, $table, $fieldname, $type, $primary, $default) = @_;
	my $sql;

	return 0 if(($table eq '') || ($fieldname eq '') || ($type eq ''));

    if(not defined $default)
	{
		if($type =~ /^int/i)
		{
			$default = 0;
		}
		else
		{
			$default = '';
		}
	}
	elsif($type =~ /^text/i)
	{
		# Text blobs cannot have default strings.  They need to be empty.
		$default = '';
	}
	
	$sql = "ALTER TABLE $table ADD $fieldname $type";
	$sql .= " DEFAULT \"$default\" NOT NULL";

	$this->executeQuery($sql);

	if($primary)
	{
		# This requires a little bit of work.  We need to figure out what
		# primary keys already exist, drop them, and then add them all
		# back in with the new key.
		my @fields = $this->getFieldsHash($table);
		my @prikeys;
		my $primaries;

		foreach my $field (@fields)
		{
			push @prikeys, $$field{Field} if($$field{Key} eq 'PRI');
		}

		$this->executeQuery("ALTER TABLE $table DROP PRIMARY KEY") if(@prikeys > 0);

		push @prikeys, $fieldname; # add the new field to the primaries
		$primaries = join ',', @prikeys;
		$this->executeQuery("ALTER TABLE $table ADD PRIMARY KEY($primaries)");
	}

	return 1;
}


#############################################################################
#	Sub
#		dropFieldFromTable
#
#	Purpose
#		Remove a field from the given table.
#
#	Parameters
#		$table - the table to remove the field from
#		$field - the field to drop
#
#	Returns
#		1 if successful, 0 if failure
#
sub dropFieldFromTable
{
	my ($this, $table, $field) = @_;
	my $sql;

	$table = $this->quote($table);
	$field = $this->quote($field);
	$sql = "ALTER TABLE $table DROP $field";

	return $this->executeQuery($sql);
}


#############################################################################
#	Sub
#		quote
#
#	Purpose
#		A quick access to DBI's quote function for quoting strings so that
#		they do not affect the sql queries.
#
#	Paramters
#		$str - the string to quote
#
#	Returns
#		The quoted string
#
sub quote
{
	my ($this, $str) = @_;

	return ($this->{dbh}->quote($str));
}


#############################################################################
#	Sub
#		genWhereString
#
#	Purpose
#		This code was stripped from selectNodeWhere.  This takes a WHERE
#		hash and a string for ordering and generates the appropriate where
#		string to pass along with a select-type sql command.  The code is
#		in this function so we can re-use it.
#
#	Notes
# 		You will note that this is not a full-featured WHERE generator --
# 		there is no way to do "field1=foo OR field2=bar" 
# 		you can only OR on the same field and AND on different fields
# 		I haven't had to worry about it yet.  That day may come
#
#	Parameters
#		WHERE - a reference to a hash that contains the criteria (ie
#			title => 'the node', etc).
#		TYPE - a hash reference to the nodetype
#		orderby - a string that contains information on how the sql
#			query should order the result if more than one match is found.
#
#	Returns
#		A string that can be used for the sql query.
#
sub genWhereString
{
	my ($this, $WHERE, $TYPE, $orderby) = @_;
	my $wherestr = '';
	my $tempstr;

	if (UNIVERSAL::isa($WHERE,'HASH')) {
	foreach my $key (keys %$WHERE)
	{
		$tempstr = '';

		# if your where hash includes a hash to a node, you probably really
		# want to compare the ID of the node, not the hash reference.
		if (UNIVERSAL::isa($$WHERE{$key}, 'HASH'))
		{
			$$WHERE{$key} = $this->getId($$WHERE{$key});
		}

		# If $key starts with a '-', it means its a single value.
		if ($key =~ /^(\-?)LIKE\-/)
		{
			my $value = $$WHERE{$key};

			if ($1 ne '-') {
				$value = $this->quote($value);
			}

			$key =~ s/^\-?LIKE\-//;
			$tempstr .= "$key LIKE $value";
		}
		elsif ($key =~ /^\-/)
		{
			$key =~ s/^\-//;
			$tempstr .= $key . '=' . $$WHERE{'-' . $key};
		}
		else
		{
			#if we have a list, we join each item with ORs
			if (ref ($$WHERE{$key}) eq 'ARRAY')
			{
				my $LIST = $$WHERE{$key};
				my $orstr = '';

				foreach my $item (@$LIST)
				{
					$orstr .= ' or ' if($orstr ne '');
					$item = $this->getId($item);
					$orstr .= $key . '=' . $this->quote($item);
				}

				$tempstr .= '(' . $orstr . ')';
			}
			elsif($$WHERE{$key})
			{
				$tempstr .= $key . '=' . $this->quote($$WHERE{$key});
			}
		}

		if($tempstr ne '')
		{
			#different elements are joined together with ANDS
			$wherestr .= " && \n" if($wherestr ne '');
			$wherestr .= $tempstr;
		}
	}
	} else { $wherestr .= $WHERE; }

	if(defined $TYPE)
	{
		$wherestr .= ' &&' if($wherestr ne '');
		$wherestr .= " type_nodetype=$$TYPE{node_id}";
	}

	$wherestr .= " ORDER BY $orderby" if $orderby;
	
	return $wherestr;
}


#############################################################################
#	"Private" functions to this module
#############################################################################


#############################################################################
sub deriveType
{
	my ($this, $TYPE) = @_;
	my $PARENT;
	my $NODETYPE;
	
	# If this type has been derived already, don't do it again.
	return $TYPE if(exists $$TYPE{resolvedInheritance});

	# Make a copy of the TYPE.  We don't want to change whatever is stored
	# in the cache if static nodetypes are turned off.
	foreach my $field (keys %$TYPE)
	{
		$$NODETYPE{$field} = $$TYPE{$field};
	}

	$$NODETYPE{sqltablelist} = $$NODETYPE{sqltable};
	if(not defined $$NODETYPE{sqltablelist})
	{
		# We'll want a cleaner way of doing this, for now this suppresses errors on bootstrap
		$$NODETYPE{sqltablelist} = '';
	}

	$PARENT = $this->getType($$NODETYPE{extends_nodetype});

	if(defined $PARENT)
	{
		foreach my $field (keys %$PARENT)
		{
			# We add some fields that are not apart of the actual
			# node, skip these because they are never inherited
			# anyway. (if more custom fields are added, add them
			# here.  We don't want to inherit them.)
			my %skipfields = (
				'tableArray' => 1,
				'resolvedInheritance' => 1 );

			next if(exists $skipfields{$field});
			next if(not defined $$NODETYPE{$field});
			# If a field in a nodetype is '-1', this field is derived from
			# its parent.
			if($$NODETYPE{$field} eq '-1')
			{
				$$NODETYPE{$field} = $$PARENT{$field};
			}
			elsif(($field eq 'sqltablelist') && defined($$PARENT{$field}))
			{
				# Inherited sqltables are added onto the list.  Derived
				# nodetypes "extend" parent nodetypes.
				$$NODETYPE{$field} .= ',' if($$NODETYPE{$field} ne '');
				$$NODETYPE{$field} .= "$$PARENT{$field}";
			}
			elsif(($field eq 'grouptable') && defined($$PARENT{$field}) &&
				($$NODETYPE{$field} eq ''))
			{
				# We are inheriting from a group nodetype and we have not
				# specified a grouptable, so we will use the same table
				# as our parent nodetype.
				$$NODETYPE{$field} = $$PARENT{$field};
			}
		}
	}

	$this->getNodetypeTables($NODETYPE);

	# If this is the 'nodetype' nodetype, we need to reassign the 'type'
	# field to point to this completed nodetype.
	if($$NODETYPE{title} eq 'nodetype')
	{
		$$NODETYPE{type} = $NODETYPE;
	}
	
	# Flag this nodetype as complete.  We use this for checking to make
	# sure that it is a valid nodetype.  This should be the only place
	# that this flag gets set!
	$$NODETYPE{resolvedInheritance} = 1;

	return $NODETYPE;
}


#############################################################################
#	Sub
#		getNodetypeTables
#
#	Purpose
#		Returns an array of all the tables that a given nodetype joins on.
#		This will create the array, if it has not already created it.
#
#	Parameters
#		typeNameOrId - The string name or integer Id of the nodetype
#
#	Returns
#		A reference to an array that contains the names of the tables
#		to join on.  If the nodetype does not join on any tables, the
#		array is empty.
#
sub getNodetypeTables
{
	my ($this, $TYPE) = @_;
	$TYPE = $this->getType($TYPE) unless ref $TYPE;
	my $tables;
	my @tablelist;
	my @nodupes;
	my $warn = '';

	if(defined $$TYPE{tableArray})
	{
		# We already calculated this, return it.
		return $$TYPE{tableArray};
	}

	$tables = $$TYPE{sqltablelist};

	if((defined $tables) && ($tables ne ''))
	{
		my %tablehash;

		# remove all spaces (table names should not have spaces in them)
		$tables =~ s/ //g;

		# Remove any crap that the user may put in there (stray commas, etc).
		$tables =~ s/,{2,}/,/g;
		$tables =~ s/^,//;
		$tables =~ s/,$//;

		@tablelist = split ',', $tables;

		# Make sure there are no dupes!
		foreach (@tablelist)
		{
			if(defined $tablehash{$_})
			{
				$tablehash{$_} = $tablehash{$_} + 1;
			}
			else
			{
				$tablehash{$_} = 1;
			}
		}

		foreach (keys %tablehash)
		{
			$warn .= "table '$_' : $tablehash{$_}\n" if($tablehash{$_} > 1);
			push @nodupes, $_;
		}

		if($warn ne '')
		{
			$warn = 'WARNING: Duplicate tables for nodetype ' .
				$$TYPE{title} . ":\n" . $warn;

			Everything::printLog($warn);
		}

		# Store the table array in case we need it again.
		$$TYPE{tableArray} = \@nodupes;
	}
	else
	{
		my @emptyArray;
		
		# Just an empty array.
		$$TYPE{tableArray} = \@emptyArray;
	}

	return $$TYPE{tableArray};
}

sub findMaintenance
{
	my ($this, $TYPE, $op) = @_;
	my $maintain;
	my $code;
	my %WHEREHASH;
	my $done = 0;

	# If the maintenance nodetype has not been loaded, don't try to do
	# any thing (the only time this should happen is when we are
	# importing everything from scratch).
	return 0 if(not defined $this->getType('maintenance'));

	# Maintenance code is inherited by derived nodetypes.  This will
	# find a maintenance code from parent nodetypes (if necessary).
	do
	{
		undef %WHEREHASH;

		%WHEREHASH = (
			-maintain_nodetype => $$TYPE{node_id}, maintaintype => $op);

		$maintain = $this->selectNodeWhere(\%WHEREHASH,
			$this->getType('maintenance'));

		if(not defined $maintain)
		{
			# We did not find any code for the given type.  Run up the
			# inheritance hierarchy to see if we can find anything.
			if($$TYPE{extends_nodetype})
			{
				$TYPE = $this->getType($$TYPE{extends_nodetype});
			}
			else
			{
				# We have hit the top of the inheritance hierarchy for this
				# nodetype and we haven't found any maintenance code.
				return 0;
			}
		}
	} until(defined $maintain);

        return $maintain->[0];

}


#############################################################################
#	Sub
#		nodeMaintenance
#
#	Purpose
#		Some nodetypes need to do some special stuff when a node is
#		created, updated, or deleted.  Maintenance nodes (similar to
#		htmlpages) can be created to have code that knows how to
#		maintain nodes of that nodetype.  You can kind of think of
#		maintenance pages as constructors and destructors for nodes of
#		a particular nodetype.
#
#	Parameters
#		$node_id -  a node hash or id that is being affected
#		$op - the operation being performed (typically, 'create', 'update',
#			or 'delete')
#
#	Returns
#		0 if error.  1 otherwiwse.
#
sub nodeMaintenance
{
	my ($this, $node_id, $op) = @_;

	my $thisnode = $node_id;
        getRef($thisnode);
        return unless $thisnode;
        my $maintenance_name = $thisnode->{type}->{title}.'_'.$op;
        if(my $delegation = Everything::Delegation::maintenance->can($maintenance_name))
        {
		return $delegation->($this, $Everything::HTML::query, $Everything::HTML::GNODE, $Everything::HTML::USER, $Everything::HTML::VARS, $Everything::HTML::PAGELOAD, $Everything::APP, $node_id);
	}else{
		return;
	}
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
	my ($this, $arg) = @_;

	if (UNIVERSAL::isa($arg, 'HASH')) {$arg = $$arg{node_id};}
	return $arg;
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
	my $this = shift @_;
	
	for (my $i = 0; $i < @_; $i++)
	{ 
		unless (ref ($_[$i]))
		{
			$_[$i] = $this->getNodeById($_[$i]) if($_[$i]);
		}
	}
	
	return ref $_[0];
}


#############################################################################
#	Sub
#		isNodetype
#
#	Purpose
#		Checks to see if the given node is nodetype or not.
#
#	Parameters
#		$NODE - the node to check
#
#	Returns
#		true if the node is a nodetype, false otherwise.
#
sub isNodetype
{
	my ($this, $NODE) = @_;
	$this->getRef($NODE);

	return 0 if (not ref $NODE);

	# If this node's type is a nodetype, its a nodetype.
	my $TYPE = $this->getType('nodetype');
	return ($$NODE{type_nodetype} == $$TYPE{node_id});
}


#############################################################################
#	Sub
#		isGroup
#
#	Purpose
#		Check to see if a nodetpye is a group.  Groups have a value
#		in the grouptable field.
#
#	Parameters
#		$NODETYPE - the node hash or hashreference to a nodetype node.
#
#	Returns
#		The name of the grouptable if the nodetype is a group, 0 (false)
#		otherwise.
#
sub isGroup
{
	my ($this, $NODETYPE) = @_;
	my $groupTable;
	$this->getRef($NODETYPE);
	
	$groupTable = $$NODETYPE{grouptable};

	return $groupTable if($groupTable);

	return 0;
}


#############################################################################
sub canCreateNode {
	#returns true if nothing is set
	my ($this, $USER, $TYPE) = @_;
	$this->getRef($TYPE);

	return 1 unless $$TYPE{writers_user};
	return $this->isApproved ($USER, $$TYPE{writers_user});
}


#############################################################################
sub canDeleteNode {
	#returns false if nothing is set (except for SU)
	my ($this, $USER, $NODE) = @_;
	$this->getRef($NODE);

	return 0 if((not defined $NODE) || ($NODE == 0));
	return $this->isApproved($USER, $$NODE{type}{deleters_user});
}


#############################################################################
sub canUpdateNode {
	my ($this, $USER, $NODE) = @_;
	$this->getRef($NODE);
	return 0 if((not defined $NODE) || ($NODE == 0));
	$EDS ||= $this->getNode('content editors', 'usergroup');
	my $type = $$NODE{type}{title};
	# Check if user is in content editors (using isApproved to handle nested groups)
	if (grep {/^$type$/}('writeup','document','oppressor_document','category')) {
		return 1 if $this->isApproved($USER, $EDS);
	}
	return $this->isApproved ($USER, $$NODE{author_user});
}


#############################################################################
sub canReadNode { 
	#returns true if nothing is set
	my ($this, $USER, $NODE) = @_;

	$this->getRef($NODE);

	return 0 if((not defined $NODE) || ($NODE == 0));
	return 1 unless $$NODE{type}{readers_user};
	return $this->isApproved($USER, $$NODE{type}{readers_user});
}


#############################################################################
#	Sub
#		isApproved
#
#	Purpose
#		Checks to see if the given user is approved within a given group 
#
#	Parameters
#		$user - reference to a user node hash  (-1 if super user)
#		$NODE - reference to a nodegroup that the user might be in 
#
#	Returns
#		true if the user is authorized, false otherwise
#
sub isApproved
{
	my ($this, $USER, $NODE, $NOGODS) = @_;

	return 0 if(not defined $USER);
	return 0 if(not defined $NODE);

	return 1 if(not defined($NOGODS) and $this->isGod($USER));

	my $user_id = $this->getId($USER);
	return 0 unless defined $user_id;
	my $node_id = $this->getId($NODE);
	return 0 unless defined $node_id;
	return 1 if ($user_id == $node_id);

	#you're always approved if it's yourself...

	$this->getRef($NODE);

	# Only cache and check group membership for actual group nodes.
	# Non-group nodes (like users) have no members besides themselves,
	# and caching them pollutes the groupCache with user nodes.
	return 0 unless $this->isGroup($$NODE{type});

	# If we short circuit out the flattening, it's a performance gain
	$this->groupCache($NODE, $this->selectNodegroupFlat($NODE)) unless $this->hasGroupCache($NODE);
	return $this->existsInGroupCache($NODE, $user_id);
}


#############################################################################
#	Sub
#		isGod
#
#	Purpose
#		Checks to see if a user is in the gods group.  This includes root
#		and '-1' as gods.  This also checks sub groups so you can have
#		other usergroups in the gods group.
#
#	Parameters
#		$USER - an id or HASH ref to a user node.
#
#	Returns
#		1 if the user is a god, 0 otherwise
#
sub isGod
{
	my ($this, $USER) = @_;
	my $user_id;
	my $usergroup;
	my $GODS;

	return 1 if($USER == -1);

	$this->getRef($USER);

	$user_id = $this->getId($USER);
	$usergroup = $this->getType('usergroup');

	($GODS) = $this->getNode('gods', $usergroup);

	$this->groupCache($GODS, $$GODS{group}, 'plain') unless $this->hasGroupCache($GODS);
	return $this->existsInGroupCache($GODS, $user_id);
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
	my ($this, $NODE) = @_;

	return $this->flattenNodegroup($NODE);
}


#############################################################################
#	Sub
#		flattenNodegroup
#
#	Purpose
#		Returns an array of node hashes that all belong to the given
#		group.  If the given node is not a group, its just assumed that
#		a single node is in its own "group".
#
#	Parameters
#		$NODE - the node (preferably a group node) in which to get the
#			nodes that are within its group.
#
#	Returns
#		An array of node hashrefs of all of the nodes in this group.
#
sub flattenNodegroup
{
	my ($this, $NODE, $groupsTraversed) = @_;
	my @listref;
	my $group;

	return if (not defined $NODE);

	# If groupsTraversed is not defined, initialize it to an empty
	# hash reference.
	$groupsTraversed ||= {};  # anonymous empty hash

	$this->getRef($NODE);

	if ($this->isGroup($$NODE{type}))
	{
		# return if we have already been through this group.  Otherwise,
		# we will get stuck in infinite recursion.
		return if($$groupsTraversed{$$NODE{node_id}});
		$$groupsTraversed{$$NODE{node_id}} = $$NODE{node_id};

		foreach my $groupref (@{ $$NODE{group} })
		{
			$group = $this->flattenNodegroup($groupref);
			push(@listref, @$group) if(defined $group);
		}

		return \@listref;
  	}
	else
	{ 
		return [$NODE];
	}
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
#		The group NODE hash that has been refreshed after the insert.
#		undef if the user does not have permissions to change this group.
#
sub insertIntoNodegroup
{
	my ($this, $NODE, $USER, $insert, $orderby) = @_;
	$this->getRef($NODE);
	my $insertref;
	my $TYPE;
	my $groupTable;
	my $nodegroup_rank;
	my $nodegroup_rank_column = $this->nodegroupRankColumn;

	return unless($this->canUpdateNode ($USER, $NODE));

	$TYPE = $NODE->{type};
	$groupTable = $this->isGroup($TYPE);

	# We need a nodetype, darn it!
	if(not defined $TYPE)
	{
		return 0;
	}
	elsif(not $groupTable)
	{
		return 0;
	}

	if(ref ($insert) eq 'ARRAY')
	{
		$insertref = $insert;

		# If we have an array, the order is specified by the order of
		# the elements in the array.
		undef $orderby;
	}
	else
	{
		#converts to a list reference w/ 1 element if we get a scalar
		$insertref = [$insert];
	}

	foreach my $INSERT (@{$insertref})
	{
		$this->getRef($INSERT);
		my $maxOrderBy;

		# This will return a value if the select is not empty.  If
		# it is empty (there is nothing in the group) it will be null.
		($maxOrderBy) = $this->sqlSelect('MAX(orderby)', $groupTable, $groupTable . "_id=$$NODE{node_id}");

		if (defined $maxOrderBy)
		{
			# The group is not empty.  We may need to change some ordering
			# information.
			if ((defined $orderby) && ($orderby <= $maxOrderBy))
			{
				# The caller of this function specified an order position
				# for the new node in the group.  We need to make a spot
				# for it.  To do this, we will increment each orderby
				# field that is the same or higher than the orderby given.
				# If orderby is greater than the current max orderby, we
				# don't need to do this.
				$this->sqlUpdate($groupTable, { '-orderby' => 'orderby+1' },
					$groupTable. "_id=$$NODE{node_id} && orderby>=$orderby");
			}
			elsif(not defined $orderby)
			{
				$orderby = $maxOrderBy+1;
			}
		}
		elsif(not defined $orderby)
		{
			$orderby = 0;  # start it off
		}

		$nodegroup_rank = $this->sqlSelect("MAX($nodegroup_rank_column)", $groupTable, $groupTable . "_id=$$NODE{node_id}");

		# If rank exists, increment it.  Otherwise, start it off at zero.
		$nodegroup_rank = ((defined $nodegroup_rank) ? $nodegroup_rank+1 : 0);

		$this->sqlInsert($groupTable, { $groupTable . '_id' => $$NODE{node_id},
			$nodegroup_rank_column => $nodegroup_rank, node_id => $$INSERT{node_id},
			orderby => $orderby});

		# if we have more than one, we need to clear this so the other
		# inserts work.
		undef $orderby;
	}

	#we should also refresh the group list ref stuff
	$this->{cache}->incrementGlobalVersion($NODE);
	$_[1] = $this->getNodeById($NODE, 'force'); #refresh the group
	return $_[1];
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
	my ($this, $GROUP, $NODE, $USER) = @_;
	$this->getRef($GROUP);
	my $groupTable;
	my $success;
	
	($groupTable = $this->isGroup($$GROUP{type})) or return; 
	$this->canUpdateNode($USER, $GROUP) or return; 

	my $node_id = $this->getId($NODE);

	$success = $this->sqlDelete ($groupTable,
		$groupTable . "_id=$$GROUP{node_id} && node_id=$node_id");

	if($success)
	{
	 $this->{cache}->incrementGlobalVersion($NODE);
		# If the delete did something, we need to refresh this group node.	
		$_[1] = $this->getNodeById($GROUP, 'force'); #refresh the group
	}

	return $_[1];
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
	my ($this, $GROUP, $REPLACE, $USER) = @_;
	$this->getRef($GROUP);
	my $groupTable;

	$this->canUpdateNode($USER, $GROUP) or return; 
	($groupTable = $this->isGroup($$GROUP{type})) or return; 
	
	$this->sqlDelete ($groupTable, $groupTable . "_id=$$GROUP{node_id}");

	return $this->insertIntoNodegroup ($_[1], $USER, $REPLACE);  
}


sub createMysqlProcedure
{
	my ($this, $procname, $parameters, $procbody, $type, $testonly) = @_;

	$parameters = '' unless defined($parameters);

	return unless defined($procname) and defined($procbody);
	return unless $procname =~ /\S/ and $procbody =~ /\S/;

	$type = 'PROCEDURE' unless(defined $type and $type ne '');
	$procbody =~ s/\r\n/\n/smg;
	if(!$testonly)
	{
		my $testresult = $this->createMysqlProcedure("ecore_test_$procname", $parameters, $procbody, $type, 1);
		if(ref $testresult ne 'ARRAY' or $testresult->[0] == 0)
		{
			return [0,$this->{dbh}->errstr];
		}else{
			$this->dropMysqlProcedure("ecore_test_$procname", $type);
		}
	}

	$this->{dbh}->{'AutoCommit'} = 0;
	$this->{dbh}->{'RaiseError'} = 1;
	$this->dropMysqlProcedure($procname, $type);

	my $create_procedure = '';
	$create_procedure .= "CREATE $type $procname($parameters)\n";
	$create_procedure .= "BEGIN\n";
	$create_procedure .= "$procbody\n";
	$create_procedure .= "END\n";


	my $return_value = [1,''];
	try {
		eval {
			$this->{dbh}->do($create_procedure);
			$this->{dbh}->commit();
		} or do {
			$return_value = [0, $@];
		}
	} catch {
		$return_value = [0, $_];
	};

	$this->{dbh}->{'AutoCommit'} = 1;
	$this->{dbh}->{'RaiseError'} = 0;

	return $return_value;
}

sub dropMysqlProcedure
{
	my ($this, $procname, $type) = @_;

	return unless defined($procname) and $procname =~ /\S/;
	$type = 'PROCEDURE' unless(defined $type and $type ne '');

	return $this->{dbh}->do("DROP $type IF EXISTS $procname");
}

sub getNodeParam
{
	my ($this, $NODE, $paramname) = @_;
	return unless defined($NODE);
	return unless defined($paramname);

	my $node_id;
	# We want to avoid using getNode here, just go with the node_id if we have it;

	if(ref $NODE eq '')
	{
		$node_id = $NODE;
	}else{
		$node_id = $NODE->{node_id};
	}

	return unless $node_id;

	my $result = $this->{cache}->getCachedNodeParam($node_id, $paramname);

	return $result if defined $result;
	my ($paramvalue) = $this->sqlSelect('paramvalue','nodeparam','node_id='.$this->quote($node_id).' and paramkey='.$this->quote($paramname));
	$this->{cache}->setCachedNodeParam($node_id, $paramname, $paramvalue);

	return $paramvalue;
}

sub getNodeParams
{
	my ($this, $NODE) = @_;
	return unless defined($NODE);

	my $node_id;
	# We want to avoid using getNode here, just go with the node_id if we have it;

	if(ref $NODE eq '')
	{
		$node_id = $NODE;
	}else{
		$node_id = $NODE->{node_id};
	}

	return unless $node_id;

	my $params;
	my $csr = $this->sqlSelectMany('*','nodeparam','node_id='.$this->quote($node_id));
	while(my $row = $csr->fetchrow_hashref())
	{
		$params->{$row->{paramkey}} = $row->{paramvalue};
		$this->{cache}->setCachedNodeParam($node_id, $row->{paramkey}, $row->{paramvalue});
	}

	return $params;
}

sub setNodeParam
{
	my ($this, $NODE, $paramname, $paramvalue) = @_;
	return unless defined($NODE);
	return unless defined($paramname);

	my $node_id;
	# We want to avoid using getNode here, just go with the node_id if we have it;

	if(ref $NODE eq '')
	{
		$node_id = $NODE;
	}else{
		$node_id = $NODE->{node_id};
	}

	return unless $node_id;
	$this->executeQuery('INSERT into nodeparam VALUES('.join(',',$this->quote($node_id),$this->quote($paramname),$this->quote($paramvalue)).') ON DUPLICATE KEY UPDATE paramvalue='.$this->quote($paramvalue));
	return $this->{cache}->setCachedNodeParam($node_id, $paramname, $paramvalue);
}

sub getNodesWithParam
{
	my ($this, $paramname, $paramvalue) = @_;
	return unless defined($paramname);

	my $select_param_value = '';
	if(defined $paramvalue)
	{
		$select_param_value = ' and paramvalue='.$this->quote($paramvalue);
	}

	my $csr = $this->sqlSelectMany('node_id','nodeparam','paramkey='.$this->quote($paramname).$select_param_value);
	my $output;
	while(my $row = $csr->fetchrow_arrayref())
	{
		push @$output, $row->[0];
	}
	return $output;
}

sub deleteNodeParam
{
	my ($this, $NODE, $paramname) = @_;
	return unless defined($NODE);
	return unless defined($paramname);

	my $node_id;
	# We want to avoid using getNode here, just go with the node_id if we have it;

	if(ref $NODE eq '')
	{
		$node_id = $NODE;
	}else{
		$node_id = $NODE->{node_id};
	}

	return unless $node_id;

	$this->sqlDelete('nodeparam','node_id='.$this->quote($node_id).' and paramkey='.$this->quote($paramname));
	return $this->{cache}->deleteCachedNodeParam($node_id,$paramname);
}

sub stashData
{
  my ($this, $stash_name, $stash_values) = @_;

  # TODO: Add to permanent cache
  my $stashnode = $this->getNode($stash_name, 'datastash');
  return unless $stashnode;

  my $json = JSON->new;
  if(defined($stash_values))
  {
    # write operation
    my $stash_text = $json->encode($stash_values);
    $stashnode->{vars} = $stash_text;
    $this->updateNode($stashnode, -1);
    return $stash_values;
  }else{
    # read operation
    return $json->decode($stashnode->{vars});
  }
}

#############################################################################
#	GroupCache code
#############################################################################

sub hasGroupCache {
	my $this = shift;
	return $this->{cache}->hasGroupCache(@_);
}

sub getGroupCache {
	my $this = shift;
	return $this->{cache}->getGroupCache(@_);
}

sub groupCache {
	my $this = shift;
	return $this->{cache}->groupCache(@_);
}

sub groupUncache {
	my $this = shift;
	return $this->{cache}->groupUncache(@_);
}

sub existsInGroupCache {
	my $this = shift;
	return $this->{cache}->existsInGroupCache(@_);
}

sub nodegroupRankColumn {
  return 'nodegroup_rank';
}

#############################################################################
#	End of Package
#############################################################################

1;
