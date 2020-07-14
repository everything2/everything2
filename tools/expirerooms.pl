#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Everything;
use Everything::HTML;
initEverything 'everything';


my $csr = $DB->sqlSelectMany("roomdata_id", "roomdata", "UNIX_TIMESTAMP(lastused_date) <= ".(time()-60*60*24*90)); # Expire after 3 months' disuse

my %exceptions = map { getNode($_, "room")->{node_id} => 1} ("Valhalla", "Political Asylum", "M-Noder Washroom", "Noders Nursery", "Debriefing Room");

while(my $row = $csr->fetchrow_hashref)
{
	my $N = getNodeById($row->{roomdata_id});
	next unless $N;
	next if $exceptions{$N->{node_id}};

	nukeNode($N, -1);
	#print $N->{title}."\n";
}
