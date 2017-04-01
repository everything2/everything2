#!/usr/bin/perl -w

use lib qw(/var/everything/ecore);
use Everything;
use Everything::APIRouter;

initEverything;

use vars qw($APIr);

# Inside of mod_perl this should start initialized
unless($APIr)
{
  Everything::printLog("Creating new APIRouter object");
  $APIr ||= Everything::APIRouter->new();
}

return $APIr->dispatcher;

