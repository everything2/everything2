#!/usr/bin/perl -w

use strict;
use lib qw(lib);

use ecoretool::base;
package ecoretool::help;
use base qw(ecoretool::base);

sub main
{
	my $topic = $ARGV[1];
	
	my $obj;
	$topic =~ s/\W//g;
	eval("require ecoretool::$topic; \$obj = ecoretool::$topic->new()");
	
	if(defined($obj))
	{
		$obj->help();
	}else{
		print "No help available for $topic";
	}
}

sub shortdesc
{
	return "Show help for a particular module. ecoretool.pl help <module>";
}

1;
