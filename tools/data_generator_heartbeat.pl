#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

print "Starting data generator: ".localtime()." (".time().")\n";

my $force;
$force = 1 if defined($ARGV[0]) and $ARGV[0] eq "force";

foreach my $plugin (@{$FACTORY->{datastash}->all})
{
    print "Evaluating generator '$plugin'...";
    my $generator = $FACTORY->{datastash}->available($plugin)->new();
    print "".($generator->generate_if_needed($force)?("updated"):("not needed"))."\n";
}

print "Finished data generator: ".localtime()." (".time().")\n";
