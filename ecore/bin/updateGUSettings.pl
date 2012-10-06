#!/usr/bin/perl -w -I /var/everything/ecore

use strict;
use Everything;
use Everything::HTML;

initEverything "everything";

my $USER = getNode 'guest user', 'user';

my $V = getVars($USER);
$$V{preferred_theme} = 1854183; 
$$V{userstyle} = 1882070;
$$V{zenadinheader} = 1;
setVars($USER, $V);

