#!/usr/bin/perl -w

use strict;
use XML::Simple qw(XMLin);

my $xs = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
my $moves;

foreach my $file(`find nodepack.pre/ -type f`)
{
	chomp $file;
	print "Inspecting $file...\n";
	my $prexml = $xs->XMLin($file);
	
	$file =~ s/^nodepack\.pre/nodepack.live/g;
	print "...against $file...\n";
	next unless -e $file;
	my $livexml = $xs->XMLin($file);

	if($prexml->{node}->{node_id} != $livexml->{node}->{node_id})
	{
		$moves->{$prexml->{node}->{node_id}} = $livexml->{node}->{node_id};
	}
}

foreach my $from(keys %$moves)
{
	my $to = $moves->{$from};
	print "Moving from:$from to:$to\n";
	`/var/everything/tools/ecoretool.pl nodeidmove --from=$from --to=$to`;
}
