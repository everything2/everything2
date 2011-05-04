#!/usr/bin/perl -w -I /var/everything/ecore

use Everything;
initEverything 'everything';

$DB->sqlDelete("message", "for_user=0 and now()-tstamp > 500");
#clean up the chatterbox table


