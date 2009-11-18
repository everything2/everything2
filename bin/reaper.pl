#!/usr/local/bin/perl -w

use strict;
use Everything;
use Everything::HTML;
initEverything 'everything', 0, { servers => ["127.0.0.1:11211"] };

my $ROW = getNode 'node row','superdoc';

my $csr = $DB->sqlSelectMany("*",'weblog', "weblog_id=".getId($ROW) . " and removedby_user=0");

open MYLOG, ">> /usr/local/everything/log/noderowlog" or die "CRAP!  Can't open me logfile!";

while (my $LOG = $csr->fetchrow_hashref) {
	my $U = getNode $$LOG{linkedby_user};
	my $N = getNode $$LOG{to_node};
	next unless $N;
	# sleep 5;
	nukeNode ($N, -1);
	$DB->sqlUpdate("tomb", { killa_user => $$U{node_id} }, "node_id=$$N{node_id}");
	print MYLOG "$$U{title} marked $$N{title} ($$N{node_id}) for death $$LOG{linkedtime}\n";
}

$DB->sqlDelete("weblog", "weblog_id=".getId($ROW)." and UNIX_TIMESTAMP(now())-UNIX_TIMESTAMP(linkedtime) > 24*360"); 
close MYLOG;
