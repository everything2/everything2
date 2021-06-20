#!/usr/bin/perl -w

use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use strict;
use Everything;
initEverything 'everything';

$APP->process_reaper_targets;
