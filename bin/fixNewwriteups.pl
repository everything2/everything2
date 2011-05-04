#!/usr/bin/perl -w -I /var/everything/ecore

use Everything;
use Everything::HTML;
initEverything 'everything';

open MYLOG, ">>/usr/local/everything/log/nwlog";

my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=117 and title='new writeup'");
print MYLOG "new killing session ". localtime(time) ."\n";
while (my ($N) = $csr->fetchrow) {
	nukeNode($N, -1);
	print MYLOG "Killed new writeup $N...\n";
}
$csr->finish;

close MYLOG;
