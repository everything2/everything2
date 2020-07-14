#!/usr/bin/perl -w

use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);

use Everything;
initEverything 'everything';

my %ins = (-stattime => 'now()');

$ins{numwriteups} = $DB->sqlSelect("count(*)", 'writeup');
$ins{nume2nodes} = $DB->sqlSelect("count(*)", 'e2node');
$ins{numusers} = $DB->sqlSelect("count(*)", 'user');
$ins{numlinks} = $DB->sqlSelect("count(*)", 'links');
$ins{xpsum} = $DB->sqlSelect("sum(experience)", 'user')-1200000;
$ins{nodehits} = $DB->sqlSelect("sum(hits)", "hits");
$ins{numedcools} = $DB->sqlSelect("count(*)", 'nodegroup', "nodegroup_id=".getId(getNode('coolnodes','nodegroup')));
$ins{numcools} = $DB->sqlSelect("count(*)", 'coolwriteups');
$ins{numvotes} = $DB->sqlSelect("count(*)", 'vote');

#foreach (keys %ins) {
#  print "$_: $ins{$_}\n";
#}

$DB->sqlInsert("stats", \%ins);



