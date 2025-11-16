#!/usr/bin/perl -w

use strict;
package ecoretool::base;
use XML::Simple qw(:strict);
use Getopt::Long;

sub new
{
	my ($class) = @_;
	my $this;
	$this->{xs} = XML::Simple->new("NoAttr" => 1, "KeepRoot" => 1, "SuppressEmpty" => 1, "NumericEscape" => 2, "ForceArray" => 0, "KeyAttr" => {});
	return bless $this,$class;
}


sub _inputs
{
	return {};
}

sub _handle_inputs
{
	my ($this) = @_;

	my $getoptargs;

	my $inputs = $this->_inputs();

	my $options;

	foreach my $input_key(keys %$inputs)
	{
		if(not defined($inputs->{$input_key}->{alias}))
		{
			$inputs->{$input_key}->{alias} = [];
		}

		my $firstarg = join("|",$input_key,@{$inputs->{$input_key}->{alias}});
		if(exists($inputs->{$input_key}->{type}))
		{
			$firstarg.="=".$inputs->{$input_key}->{type};
		}
		push @$getoptargs,$firstarg,\$options->{$input_key};
	}

	GetOptions(@$getoptargs);

	foreach my $input_key(keys %$inputs)
	{
		if(not defined($options->{$input_key}))
		{
			$options->{$input_key} = $inputs->{$input_key}->{default};
		}
	}

	return $options;
}

sub help
{
	my ($this) = @_;
	
	my $inputs = $this->_inputs();
	my $thismodule = ref $this;
	$thismodule =~ s/.*:://g;

	print "Help for ecoretool.pl $thismodule:\n";

	my $maxlength = 0;
	foreach my $input_key (keys %$inputs)
	{
		my $thislength = length($this->_format_help_alias($input_key));
		if($maxlength < $thislength)
		{
			$maxlength = $thislength;
		}
	}

	foreach my $input_key (keys %$inputs)
	{
		my $ha = $this->_format_help_alias($input_key);
		print " $ha".(" " x ($maxlength - length($ha)))."\t".$inputs->{$input_key}->{help}."\n";
	}
	return;
}
sub _format_help_alias
{
	my ($this, $input_key) = @_;

	my $inputs = $this->_inputs();
	
	my $str = "--$input_key";

	foreach my $alias (@{$inputs->{$input_key}->{alias}})
	{
		if(length($alias) == 1)
		{
			$str.=",-$alias";
		}else{
			$str.=",--$alias";
		}
	}

	return $str;

}
sub get_worker_object
{
	my ($this, $type) = @_;

	my $obj;
	
	return unless $type; #TODO: error
	$type =~ s/-/_/g;
	eval("use Everything::ect::$type;");
	
	#TODO: Search in @INC first, don't be lazy
	eval("\$obj = Everything::ect::$type->new();");

	if(not defined($obj))
	{
		eval("\$obj = Everything::ect::node->new();");
	}

	if(not defined($obj))
	{
		print STDERR "Could not make type for $type: '$@'\n"; #TODO: error
		return;
	}

	return $obj
}

sub _skippable_types
{
	return {
		"e2node" => [],
		"writeup" => [], 
		"category" => [],
		"document" => [],
		"edevdoc" => [],
		"patch" => [],
		"user" => [113,952215,779713,839239,1080927,373682,176726,373682,373113,1527919,1988327], #root,klaproth,guest user,cool man eddie,virgil,everyone,webster 1913,everyone, EDB, Giant Teddy Bear, Fiery Teddy Bear
		"usergroup" => [838015, 114, 829913, 923653, 1199641, 1969185, 1192564, 1882128, 1175790, 1433518, 2175734, 1713398, 1797556], #Edev, gods, e2gods, content editors, clientdev, chanops,debuggers,e2docs,%%, SIGTITLE, News, Sheriffs, thepub
		"node_forward" => [],
		"ticket" => [], 
		"draft" => [],
		"podcast" => [],
		"debate" => [],
		"debatecomment" => [],
		"collaboration" => [],
		"e2poll" => [],
		"e2client" => [],
		"musicdoc" => [],
		"musicnode" => [],
		"oppressor_document" => [],
		"recording" => [],
		"registry" => [],

		# Noders Nursery, M-Noder Washroom, Political Asylum, Valhalla, Debriefing Room
		"room" => [553146,553133,553129,545263,1973457],
	};
}

sub _get_table_columns
{
	my ($this, $dbh, $table) = @_;

	my $columns;
	my $sth = $dbh->prepare("EXPLAIN $table");
	$sth->execute();
	
	while (my $row = $sth->fetchrow_hashref())
	{
		push @$columns, $row->{Field};
	}

	$sth->finish();

	return $columns;
}

1;
