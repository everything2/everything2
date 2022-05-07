#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Everything;
initEverything 'everything';

print "Starting cleaning old rooms\n";
$APP->clean_old_rooms;
print "Finished cleaning old rooms\n";
