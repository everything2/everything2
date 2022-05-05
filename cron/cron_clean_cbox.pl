#!/usr/bin/perl -w

use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);

use Everything;
initEverything 'everything';

$Everything::APP->chatterbox_cleanup;
