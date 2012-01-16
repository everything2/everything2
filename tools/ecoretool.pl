#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Clone;
use lib qw(/var/everything/ecore);

#TODO: Wrap this in BEGIN and just search for available modules
#Also generate allowed_directives

use vars qw($allowed_directives);

BEGIN
{
	unshift @INC, qw(lib /var/everything/ecore);
	foreach my $librarydir (@INC)
	{
		if (-d "$librarydir/ecoretool")
		{
			my $libdirhandle; opendir($libdirhandle, "$librarydir/ecoretool");
			foreach my $libfile (readdir($libdirhandle))
			{
				my $fullfile = "$librarydir/ecoretool/$libfile";
				next unless -f $fullfile and -e $fullfile;
				$libfile =~ s/\.pm//g;
				eval("use ecoretool::$libfile;");
				next if $libfile eq "base";	
				my $obj = "ecoretool::$libfile";
				no strict 'refs';
				print STDERR $@ if $@;
				$allowed_directives->{$libfile} = $obj->shortdesc();
			}
		}		
	}
}

my $directive = $ARGV[0];

if($directive and exists($allowed_directives->{$directive}))
{
	my $handler;
	no strict 'refs';
	my $obj = "ecoretool::$directive";
	$handler = $obj->new();	

	if(not defined $handler)
	{
		print STDERR "Internal error! Could not fire up handler: $@\n";
		exit;
	}

	$handler->main();
	exit;
	
}else{
	general_help();
	exit;
}

sub general_help
{
	print "Usage: ecoretool.pl [DIRECTIVE] [OPTIONS]\n";
	
	if(defined($directive))
	{
		print "(Unknown directive '$directive', here are your choices:)\n";
	}

	my $maxlength = 0;
	foreach my $key(keys %$allowed_directives)
	{
		$maxlength = length($key) if length($key) > $maxlength;
	}

	foreach my $key (sort {$b cmp $a} keys %$allowed_directives)
	{
		print $key.(' 'x($maxlength-length($key)))."\t".$allowed_directives->{$key}."\n";
	}
}

