#!/usr/bin/perl -w

use strict;
package ecoretool::base;

use Getopt::Long;

sub new
{
	my ($class) = @_;
	my $this;
	$this->{xs} = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
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
	eval("use Everything::node::$type;");
	
	#TODO: Search in @INC first, don't be lazy
	eval("\$obj = Everything::node::$type->new();");

	if(not defined($obj))
	{
		eval("\$obj = Everything::node::node->new();");
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
		"user" => [113,952215,779713,839239], #root,klaproth,guest user,cool man eddie
		"node_forward" => [],
		"ticket" => [], 
		"draft" => [],
		"debate" => [],
		"debatecomment" => [],
		"collaboration" => [],
		"e2poll" => [],
	};
}
1;
