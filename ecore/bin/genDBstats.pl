#!/usr/bin/perl -w

use strict;
use Everything;

initEverything 'everything';

my %stats;
my %vars;

my $csr = $dbh->prepare('show status');
$csr->execute;
while (my ($key, $val) = $csr->fetchrow) { $stats{$key} = $val }
$csr->finish;

$csr = $dbh->prepare('show variables');
$csr->execute;
while (my ($key, $val) = $csr->fetchrow) { $vars{$key} = $val }
$csr->finish;

$DB->sqlInsert("dbstats", { -tstamp => 'now()', 
	uptime => $stats{Uptime},
	slow => $stats{Slow_queries},
	questions => $stats{Questions} });

