#!/usr/bin/perl -w

use lib qw(/var/everything/ecore);
use Everything;
use Everything::APIRouter;

initEverything;

my $APIr;
$APIr ||= Everything::APIRouter->new();

return $APIr->route();

