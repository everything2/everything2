package Everything::FormMenu;

#############################################################################
#
#	Everything::FormMenu
#		A module for creating various HTML menus (popup, multi, multiple
#		selection, etc).
#
#############################################################################

use strict;
use Everything;
use Everything::HTML;

sub BEGIN
{
	use Exporter();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT = qw(
		addSettings
		addGroup
		addHashInfo
		writePopupHTML
		writeScrollingListHTML); 
}


#############################################################################
#	Sub
#		new
#
#	Purpose
#		This gets called when somebody creates a new instance of this
#		object.  We init our stuff here.
#		inheiritence added by chromatic?
#
#	Parameters
#		None
#
#	Returns
#		The new object
#
sub new
{
	my $class = shift;
	my $this = {};
	
	bless ($this, $class);

	$this->{VALUES} = [];
	$this->{LABELS} = {};

	return $this;
}


#############################################################################
#	Sub
#		addSettings
#
#	Purpose
#		Go grab the hash from the specified "setting" node and add its
#		values to the menu.
#
#	Paramters
#		$setting - the string name of the settings node that you wish
#			to add to the menu.
#		$sort - Set to true if the menu labels should  be sorted
#			alphabetically
#
sub addSettings
{
	my ($this, $setting, $sort) = @_;
	my $NODE = $DB->getNode($setting, $DB->getType("setting"));
	my $vars;
	my $key;

	return if(not defined $NODE);
	$vars = getVars($NODE);

	$this->addHash($vars, $sort);
}


#############################################################################
#	Sub
#		addType
#
#	Purpose
#		Add all nodes of the given type to the menu.  This is useful for
#		given an option to select a given user, nodetype, etc.
#
#	Parameters
#		$type - the string name of the nodetype of the nodes to add.
#		$sort - Set to true if the menu labels should  be sorted
#			alphabetically
#
sub addType
{
	my ($this, $type, $sort) = @_;
	my $TYPE = $DB->getType($type);
	my $typeid = $$TYPE{node_id} if(defined $TYPE);
	my $NODES = $DB->selectNodeWhere({type_nodetype => $typeid});
	my $NODE;
	my $gValues = $this->{VALUES};
	my @values;

	$sort ||= 0;
	
	foreach $NODE (@$NODES)
	{
		getRef $NODE;
		$this->{LABELS}->{$$NODE{node_id}} = $$NODE{title};
		push @values, $$NODE{node_id};
	}

	if($sort)
	{
		my @sorted = sort { $this->{LABELS}->{$a} cmp $this->{LABELS}->{$b} }
			@values;
		push @$gValues, @sorted;
	}
	else
	{
		push @$gValues, @values;
	}
}


#############################################################################
#	Sub
#		addGroup
#
#	Purpose
#		Given the name of the group, add all of the nodes in that group.
#
#	Parameters
#		$group - the string name of the group to add.
#		$sort - Set to true if the menu labels should  be sorted
#			alphabetically
#
sub addGroup
{
	my ($this, $group, $sort) = @_;
	my $GROUP = $DB->getNode($group);
	my $groupnode;
	my $NODE;
	my $GROUPNODES;
	my $gValues = $this->{VALUES};
	my @values;
	
	return if(not defined $GROUP);
	return if(ref $GROUP ne "HASH");

	$sort ||= 0;

	$GROUPNODES = selectNodegroupFlat($GROUP);
	foreach $groupnode (@$GROUPNODES)
	{
		$NODE = $DB->getNodeById($groupnode);
		$this->{LABELS}->{$$NODE{node_id}} = $$NODE{title};
		push @values, $$NODE{node_id};
	}

	if($sort)
	{
		my @sorted = sort { $this->{LABELS}->{$a} cmp $this->{LABELS}->{$b} }
			@values;
		push @$gValues, @sorted;
	}
	else
	{
		push @$gValues, @values;
	}
}


#############################################################################
#	Sub
#		addHash
#
#	Purpose
#		Given a hashref, add the contents to the menu.  The keys of the
#		hash should be the values of the menu.  The values of the hash
#		should be the string that is to be seen by the user.  For example,
#		if you want a popup menu with labels of "yes" and "no" and values
#		of '1' and '0', your hash should look like:
#			{ '1' => "yes", '0' => "no"}
#
#	Parameters
#		$hashref - the reference to the hash that you want to add to the
#			menu.
#		$sort - Set to true if the menu labels should  be sorted
#			alphabetically
#
sub addHash
{
	my ($this, $hashref, $sort) = @_;
	my $key;
	my $gValues = $this->{VALUES};
	my @values;

	$sort ||= 0;
	
	foreach $key (keys %$hashref)
	{
		$this->{LABELS}->{$key} = $$hashref{$key};
		push @values, $key;
	}

	if($sort)
	{
		my @sorted = sort { $this->{LABELS}->{$a} cmp $this->{LABELS}->{$b} }
			@values;
		push @$gValues, @sorted;
	}
	else
	{
		push @$gValues, @values;
	}
}


#############################################################################
#	Sub
#		writePopupHTML
#
#	Purpose
#		Based on how the menu was set up, generate the HTML for the popup
#		menu and return it.
#
#	Parameters
#		$cgi - the CGI object that we should use to create the HTML
#		$name - The string name of the form item
#		$selected - the option that is selected by default.  This is one
#			of the keys of our hash.
#
#	Returns
#		The HTML for the new form item
#
sub writePopupHTML
{
	my ($this, $cgi, $name, $selected) = @_;

	# We need a CGI object
	return "" if(not defined $cgi);

	return $cgi->popup_menu(-name => $name,
	                        -values => $this->{VALUES},
	                        -default => $selected,
	                        -labels => $this->{LABELS});
}


#############################################################################
#	Sub
#		writeScrollingListHTML
#
#	Purpose
#		Create the HTML needed for a scrolling list form item.
#
#	Parameters
#		$cgi - the CGI object that we should use to generate the HTML
#		$name - the string name of the form item
#		$selected - the name of the option that is selected by default.
#			An array reference if the default selection is more than one.
#			If blank, then nothing is selected by default.
#		$size - <optional> the number of options (lines) visible
#		$multi - <optional> 1 (true) if this list item should allow
#			multiple selections	0 (false) if not.
#
#	Returns
#		The HTML for this scrolling list form item
#
sub writeScrollingListHTML
{
	my ($this, $cgi, $name, $selected, $size, $multi) = @_;

	return "" if(not defined $cgi);

	# We want an array.  If we have a scalar, make it an array with one elem
	$selected = [$selected] if(ref $selected ne "ARRAY");

	$multi ||= 0;
	$size ||= 6;

	return $cgi->scrolling_list(-name => $name,
	                            -values => $this->{VALUES},
	                            -default => $selected,
	                            -size => $size,
	                            -multiple => $multi,
	                            -labels => $this->{LABELS});
}


#############################################################################
# End of Package Everything::FormMenu
#############################################################################

1;
