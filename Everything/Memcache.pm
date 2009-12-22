package Everything::Memcache;

#############################################################################
#
#	Everything::Memcache
#
#	This module is a very rudimentary expansion to NodeCache
#	which forms a second layer of cache inside a memcache server
#	reads occur when there is a local cache miss
#	and writes occur when there is a memcache miss
#	
#	This module also should fail gracefully if no
#	connection to MC can be established
#
#############################################################################

use strict;
use Everything;
use Cache::Memcached;

sub BEGIN
{
	use Exporter();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT = qw(
		); 
}


use vars qw($mch);


#############################################################################
#	Sub
#		new
#
#	Purpose
#		Constructs a new MC object 
#
#	Parameters
#		same as Cache::Memcached init	
#
#	Returns
#		The newly constructed module object
#
sub new
{
	my $class = shift;
	my $mcparams = shift;
	my $nodebase = shift;
	my $this = {};
	
	bless ($this, $class);
	
	if ($mch) {
		$this->{mch} = $mch;
	} else {
		$this->{mch} = new Cache::Memcached $mcparams; 
		$mch = $this->{mch};
	}
	$this->{DB} = $nodebase;
	return $this;
}


#############################################################################
#	Sub
#		setNode	
#
#	Purpose
#		install the node in the cache giving keys for name/type and 
#		by node id
#
#
#	Parameters
#		$node - The data to put in the queue
#		$expires -- optional, expiration time
#
#	Returns
#		1 on success
#
sub setNode 
{
	my ($this, $node, $expire) = @_;
	return unless $this->{mch};
	my $id = $$node{node_id}; 
	$expire ||= 0;
	my $nametypekey = $this->generateNameTypeKey($$node{title}, $$node{type}{title});

	#need to clean the node of subhashes
	my $data = $this->deconstructNode($node);

	$this->{mch}->set($id, $data, 60);
	$this->{mch}->set($nametypekey, $id, 60);
	
	return 1;
}


#############################################################################
#	Sub
#		getNode
#
#	Purpose
#		given a nodeid, return 
#
#	Parameters
#		$node_id
#
#	Returns
#		The reconstructed node 
#		or 0 on cache miss
#
sub getNode
{
	my ($this, $node_id) = @_;
	return unless $this->{mch};

	my $data = $this->{mch}->get($node_id);
	return 0 unless $data;

	return $this->reconstructNode($data);
}


#############################################################################
#	Sub
#		getNodeByNameType
#
#	Purpose
#		this is a helper function which will retrieve
#		the node from cache if we have the name/type as identifiers
#
#	Parameters
#		node name and type	
#
#	Returns
#		the desired node
#		0 on cache miss
#
sub getNodeByNameType
{
	my ($this, $title, $type) = @_;
	return unless $this->{mch};

	my $nametypekey = $this->generateNameTypeKey($title, $type);

	my $id = $this->{mch}->get($nametypekey);
	return 0 unless $id;

	return $this->getNode($id);
}


#############################################################################
#	Sub
#		expireNode	
#
#	Purpose
#		remove a node from the cache
#
#	Parameters
#		$node_id	
#
#	Returns
#		1 if success 
#
sub expireNode 
{
	my ($this, $node_id) = @_;
	return unless $this->{mch};

	return $this->delete($node_id);
}

#############################################################################
# "Private" module subroutines - users of this module should never call these
#############################################################################

#############################################################################
#	Sub
#		deconstructNode		
#
#	Purpose
#		take the data out of a node and make appropriate for caching
#
#	Parameters
#		$node -- the node to deconstruct	
#
#	Returns
#		a serializable data structure
#
sub deconstructNode 
{
	my ($this, $node) = @_;

	my $data = {};
	my %expungefields = ( 'type' => 1, '_ORIGINAL_VALUES' => '1');

	foreach (keys %$node) {
		$$data{$_} = $$node{$_} unless (exists $expungefields{$_} or ref($$node{$_}) eq 'CODE');
	}

	$$data{_memcached_version} = $this->{DB}->{cache}->getGlobalVersion($node);
	return $data;
}


#############################################################################
#	Sub
#		reconstructNode	
#
#	Purpose
#		given the serializable data structure, return a valid node	
#	Params
#		data - the serializable data structure
#
#	Returns
#		a proper node	
#
sub reconstructNode 
{
	my ($this, $data) = @_;
	
	if ($$data{node_id} == 1) {
		$$data{type} = $data;
	} else {
		$$data{type} = $this->{DB}->getType($$data{type_nodetype});
	}
	$this->{DB}->copyOriginalValues($data);
	return $data; 
}


sub generateNameTypeKey 
{
	my ($this, $title, $type) = @_;

	$title =~ s/\s/SPACE/g;
	$type =~ s/\s/SPACE/g;
	return $type . "_____NAME_____" . $title;
}


#############################################################################
#	End of Package Everything::Memcache
#############################################################################

1;
