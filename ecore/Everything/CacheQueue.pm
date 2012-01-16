package Everything::CacheQueue;

#############################################################################
#
#	Everything::CacheQueue
#		A module for maintaining a queue in which you can easily pull items
#		from the middle of the queue and put them at the end again.  This
#		is useful for caching purposes.  Every time you use an item, pull
#		it out from the queue and put it at the end again.  The result is
#		the least used items end up at the head of the queue.
#
#		The queue is implemented as a double-linked list and a data field.
#
#############################################################################

use strict;
use Everything;


sub BEGIN
{
	use Exporter();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT = qw(
		queueItem
		getNextItem
		getItem
		removeItem
		getSize
		listItems); 
}

#############################################################################
#	Sub
#		new
#
#	Purpose
#		Constructs a new CacheQueue
#
#	Parameters
#		None
#
#	Returns
#		The newly constructed module object
# constructor improved to allow inheritance -- chromatic, 30 December 1999
#
sub new
{
	my $class = shift;
	my $this = {};
	
	bless ($this, $class);
	
	$this->{queueHead} = $this->createQueueData("HEAD");
	$this->{queueTail} = $this->createQueueData("TAIL");

	# Hook them up
	$this->{queueHead}{prev} = $this->{queueTail};
	$this->{queueTail}{next} = $this->{queueHead};
	
	$this->{queueSize} = 0;

	# Keep track of how many permanent items we have in the cache.
	$this->{numPermanent} = 0;

	return $this;
}


#############################################################################
#	Sub
#		queueItem
#
#	Purpose
#		Put the given data item at the end of the queue
#
#	Parameters
#		$item - The data to put in the queue
#		$permanent - True if this item should never be returned from
#			getNextItem.  An item marked permanent can still be removed
#			manually using the removeItem function.
#
#	Returns
#		A reference to the queue data that represents the item.  Hold on
#		to this, you will need it for calls to getItem.  You should not
#		modify any data within this "object".
#
sub queueItem
{
	my ($this, $item, $permanent) = @_;
	my $data = $this->createQueueData($item, $permanent);

	$this->queueData($data);	
	
	return $data;
}


#############################################################################
#	Sub
#		getItem
#
#	Purpose
#		Given the reference to the queue data (returned from queueItem()),
#		return the user's item.  This also pulls this item out of the queue
#		and reinserts it at the end.  This way the least used items are at
#		the head of the queue.
#
#	Parameters
#		$data - the queue data representing a user's item.  This is returned
#			from queueItem().
#
#	Returns
#		The user's item
#
sub getItem
{
	my ($this, $data) = @_;

	# Since we used this item, put it back at the end (the least used will
	# work their way to head of the queue).
	$this->removeData($data);
	$this->queueData($data);
	
	return $$data{item};
}


#############################################################################
#	Sub
#		getNextItem
#
#	Purpose
#		This pulls the "oldest" item off the head of the queue.  This removes
#		the item from the queue.  Any queue data references (returned from
#		queueItem()) that you are holding for this item should be deleted.
#		If the "oldest" item is permanent, we will re-queue that item and
#		find one that is not permanent.
#
#	Parameters
#		None
#
#	Returns
#		The user's item
#
sub getNextItem
{
	my ($this) = @_;
	my $firstData = $this->{queueHead}{prev};

	while($$firstData{permanent})
	{
		# The oldest thing in the queue is permanent.  Put it at the end.
		$this->removeData($firstData);
		$this->queueData($firstData);

		$firstData = $this->{queueHead}{prev};
	}

	$this->removeData($firstData);

	return $$firstData{item};
}


#############################################################################
#	Sub
#		getSize
#
#	Purpose
#		Get the size of the queue
#
#	Parameters
#		None
#
#	Returns
#		The number of items in the queue
#
sub getSize
{
	my ($this) = @_;

	return $this->{queueSize};
}


#############################################################################
#	Sub
#		removeItem
#
#	Purpose
#		Remove an item from the queue.  This should only be used when the
#		associated item is deleted and should no longer be in the queue.
#
#	Parameters
#		$data - the queue data ref (as returned from queueItem()) to remove
#
#	Returns
#		The removed data item.
#
sub removeItem
{
	my ($this, $data) = @_;

	return undef if(not defined $data);

	$this->removeData($data);
	return $$data{item};
}


#############################################################################
#	Sub
#		listItems
#
#	Purpose
#		Return an array of each item in the queue.  Useful for checking
#		whats whats in there (mostly for debugging purposes).
#
#	Returns
#		A reference to an array that contains all of the items in the queue
#
sub listItems
{
	my ($this) = @_;
	my $data = $this->{queueTail}{next};
	my @list;

	while($$data{item} ne "HEAD")
	{
		push @list, $$data{item};
		$data = $$data{next};
	}

	return \@list;
}




#############################################################################
# "Private" module subroutines - users of this module should never call these
#############################################################################

#############################################################################
sub queueData
{
	my ($this, $data) = @_;

	$this->{numPermanent}++ if($$data{permanent});
	$this->insertData($data, $this->{queueTail});
}


#############################################################################
sub insertData
{
	my ($this, $data, $before) = @_;
	my $after = $$before{next};

	$$data{next} = $after;
	$$data{prev} = $before;
	
	$$before{next} = $data;
	$$after{prev} = $data;

	# Increment the queue size since we just added one
	$this->{queueSize}++;
}


#############################################################################
sub removeData
{
	my ($this, $data) = @_;
	my $next = $$data{next};
	my $prev = $$data{prev};

	return if($this->{queueSize} == 0);
	return if($next == 0 && $prev == 0);  # It has already been removed

	# Remove us from the list
	$$next{prev} = $prev;
	$$prev{next} = $next;
	
	# Null out our next and prev pointers
	$$data{next} = 0;
	$$data{prev} = 0;
	
	$this->{numPermanent}-- if($$data{permanent});
	$this->{queueSize}--;
}


#############################################################################
#	Sub
#		createQueueData
#
#	Purpose
#		This creates a link, in our linked list.
#
sub createQueueData
{
	my ($this, $item, $permanent) = @_;
	my $data;
	
	$permanent ||= 0;
	$data = { "item" => $item, "next" => 0, "prev" => 0,
		"permanent" => $permanent};

	return $data;
}


#############################################################################
#	End of Package Everything::CacheQueue
#############################################################################

1;
