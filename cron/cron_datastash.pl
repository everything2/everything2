#!/usr/bin/perl

use strict;
use warnings;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Getopt::Long;
use Everything;

initEverything 'everything';
my $force;
my $only;

GetOptions("force|f" => \$force, "only=s" => \$only);

print "Starting data generator: ".localtime()." (".time().")\n";

foreach my $plugin (@{$FACTORY->{datastash}->all})
{
    my $generator = $FACTORY->{datastash}->available($plugin)->new();

    if($only)
    {
      next unless $plugin eq $only;
    }

    print "Evaluating generator '$plugin'...";
    print "".($generator->generate_if_needed($force)?("updated"):("not needed"))."\n";
}

print "Finished data generator: ".localtime()." (".time().")\n";
