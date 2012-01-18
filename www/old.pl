#!/usr/bin/perl -w 

my %badips = (
'64.71.167.99' => 1,
'208.53.158.14' => 1,
'162.119.64.111' => 1 
);

$ENV{SCRIPT_NAME} =~ s/^\/+/\//;



die "you're busted" if exists $badips{$ENV{HTTP_X_FORWARDED_FOR}} or $ENV{HTTP_X_FORWARDED_FOR} =~ /^64\.71\./;
use strict;
use Everything::HTML;

$ENV{TZ} = '+0000';


mod_perlInit "everything", 0, { servers => ["127.0.0.1:11211"] };
