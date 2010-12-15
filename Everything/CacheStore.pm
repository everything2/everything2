package Everything::CacheStore;

##################################################################
#
#   Everything::CacheStore.pm
#
#   Copyright 2002 Everything Development Company
#
#		A module for keeping cached Guest User pages from HTML.pm
#
##################################################################

use strict;
use DBI;
use Everything;
use Everything::HTML;

use vars qw(%CACHESETTINGS);


##################################################################
#
# sub 
#		new
#
#  Purpose
#		Construct a cache_store object that you can use to cache HTML pages
#
#	Parameters
#		$dbname (incl. host)
#
#	Returns
#		a cache store object
#
sub new {
    my ($className, $dbname) = @_;

    my $this = {};
    bless $this; #meal
    my ($user,$pass) = ($CONFIG{'rootuser'}, $CONFIG{'rootpass'});
    $this->{dbh} = DBI->connect("DBI:mysql:$dbname", $user, $pass); 	
	if (not $this->{dbh}) {
		printErr "could not connect to cache_store";
		return 0;
	}
	%CACHESETTINGS = %{ getVars(getNode('cache_settings', 'setting')) };
	$this->{nodes} = getVars(getNode('cachable_nodes', 'setting'));
	$this->{types} = getVars(getNode('cachable_types', 'setting'));
	$this;

}

######################################################################
#
#  sub
#		cachePage
#
#  purpose
#		store a page, with timestamp, under a node id
#  
#  params
#		id 		node_id to store
#		page	html page
#
#  returns execute result on success
#
sub cachePage {
   my ($this, $id, $page) = @_;


   my $version = 0;
   $version = $DB->sqlSelect("version", "version", "version_id=$id");
   my $csr = $this->{dbh}->prepare_cached("
   		REPLACE INTO cache_store 
		(cache_store_id, page, version) 
   		values (?, ?, ?)");

   my $result = $csr->execute($id, $page, $version);

   $csr->finish;
   printErr "cache insert failed id: $id" unless $result;

   #jb says: You could also do INSERT IGNORE INTO stats.
   #You're getting duplicate key errors.. (i am not sure why), but
   #that would suppress them here. No changes made
   $this->{dbh}->do("INSERT IGNORE INTO stats (stats_id) VALUES ($id)");
    
   return $result;
}
##################################################################
#
# sub 
#	retrievePage	
#
#   Purpose
#		retrieve a cached page (w/in a time limit) 
#
#	Parameters
#		id node_id to retrieve	
#
#	Returns
#		html page	
#
sub retrievePage {
  my ($this, $id) = @_;

  my $csr  = $this->{dbh}->prepare("
  		SELECT page,version,UNIX_TIMESTAMP(tstamp),UNIX_TIMESTAMP(now()) FROM cache_store 
		WHERE cache_store_id=?
		AND expired=0
		AND UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(tstamp)
		< $CACHESETTINGS{expire}");
  
  my $result = $csr->execute($id);
  return unless $result;

  my $version = $DB->sqlSelect("version", "version", "version_id=$id");
  my ($page, $pv, $tstamp, $now) = $csr->fetchrow();
  #jb says: You're getting a pile of warnings. I added this to keep the logs cleaner
  #removeme once you've read this note.
  $pv ||= 0;
  if ($version != $pv) {
	$this->expire($id);
	$this->miss($id);
	return;
  }
  if (exists $this->{nodes}->{$id} and $this->{nodes}->{$id} < $now - $tstamp) {
    $this->expire($id); 
	$this->miss($id);
	return;
  }
  $csr->finish;

  $this->hit($id);
  return \$page if $page;
  0;
}

#
#  sub canCache
#
#  purpose determine whether a node is appropriate for caching
#  params $N - node, $query - CGI object
#
sub canCache {
  my ($this, $N, $query) = @_;

  foreach($query->param) { 
    next unless $query->param($_);
    if ($_ eq 'displaytype') {
       next if $query->param('displaytype') eq 'display' or not $query->param('displaytype');
	}
	
	next if /^(node|node_id|lastnode_id|author|type|guest)$/;
	#print "BLAM $_<BR>";
	return;
  }
  return if not exists $this->{types}{$$N{type_nodetype}}
    and not exists $this->{nodes}{$$N{node_id}};
  return 1;

}

sub expire {
	my ($this, $id) = @_;
    $this->{dbh}->do("UPDATE cache_store SET expired=1 WHERE cache_store_id=$id");
}

#log a hit for statistics
sub hit {
	my ($this, $id) = @_; 
    $this->{dbh}->do("UPDATE stats SET hits=hits+1 WHERE stats_id=$id");
}

sub miss {
	my ($this, $id) = @_;
    $this->{dbh}->do("UPDATE stats SET miss=miss+1 WHERE stats_id=$id");
}



#clean up the trash
sub clean {
  my ($this) = @_;

  $this->{dbh}->do("
  	DELETE from cache_store
	WHERE expired!=0
	OR UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(tstamp)
	> $CACHESETTINGS{expire}") or die "could not clean";
	
  1;
}

1;

