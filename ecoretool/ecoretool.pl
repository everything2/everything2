#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);

use File::Basename;
BEGIN
{
	my $basedir = dirname(__FILE__);
	unshift @INC, "$basedir/lib","$basedir/../ecore","lib","/var/libraries/lib/perl5";
}
package ecoretool;
use Getopt::Long;
use Clone;
use Module::Pluggable search_path => ['ecoretool'],search_dirs => ['lib'],except => 'ecoretool::base', instantiate => 'new';

my $allowed_directives;
my $directive = $ARGV[0];

foreach my $plugin (ecoretool::plugins())
{
	my $name = ref $plugin;
	$name =~ s/ecoretool\:://g;
	my $shortdesc = $plugin->shortdesc();
	$allowed_directives->{$name} = $shortdesc;
}

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

