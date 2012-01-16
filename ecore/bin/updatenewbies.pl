#!/usr/bin/perl -w -I /var/everything/ecore

use strict;
use Everything;
use Everything::HTML;
initEverything 'everything';

exit;

my $newb = getNode('fresh users', 'setting');
my $newbies = getVars($newb);

foreach(keys %$newbies)
{
   delete $$newbies{$_};
}

my $csr = $DB->getDatabaseHandle()->prepare("SELECT node_id, title from 
node WHERE type_nodetype=15 AND TO_DAYS(NOW()) - TO_DAYS(createtime) <= 
30");

$csr->execute();

while(my $row = $csr->fetchrow_hashref())
{
  next if($$row{node_id} == 733132); #crazyinsomniac weirdness

  $$newbies{$$row{node_id}} = $DB->sqlSelect("TO_DAYS(NOW()) - 
TO_DAYS(createtime)", "node", "node_id=$$row{node_id}")+1;
;
}

  setVars($newb, $newbies);
