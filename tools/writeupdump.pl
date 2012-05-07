#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Everything::NodeBase;

initEverything 'everything';

my $username = $ARGV[0];
if(not defined $username)
{
	print STDERR "Usage: writeupdump.pl \$USERNAME\n";
	exit;
}

my $U = getNode($username, "user");
if(not defined $U)
{
	print STDERR "Could not find user '$username'\n";
	exit;
}

my $wu = getType("writeup");
if(not defined $wu)
{
	print STDERR "Could not find writeup type\n";
	exit;
}

foreach my $writeup($DB->getNodeWhere({author_user => $U->{node_id}}, $wu))
{
	getRef($writeup);
	my $title = $writeup->{title};
	$title =~ s/\s/_/g;
	my $handle;
	open $handle,">$title.txt";
	print $handle $writeup->{doctext};
	close $handle;
}

