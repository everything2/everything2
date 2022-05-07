#!/usr/bin/perl -w

use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use strict;
use Everything;
initEverything 'everything';

print "Started writeup reaper\n";
foreach my $action (@{$APP->process_reaper_targets})
{
  print "Reaper: Killer: $action->{killer}, Node: $action->{node}\n"
}
print "Finished writeup reaper\n";
