#!/usr/bin/perl -w 

$ENV{SCRIPT_NAME} =~ s/^\/+/\//;

use strict;
use Everything::HTML;

$ENV{TZ} = '+0000';

my $staticNodetypes = 1;

mod_perlInit "everything", $staticNodetypes, { servers => ["127.0.0.1:11211"] };
