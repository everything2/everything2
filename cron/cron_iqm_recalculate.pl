#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
initEverything 'everything';

print "Starting IQM recalculation\n";
$APP->global_iqm_recalculate;
print "Finished IQM recalculation\n";
