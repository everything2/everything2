#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything::Configuration;

my $CONF = Everything::Configuration->new;

exec("mysql --default-character-set=utf8 --user=\"".$CONF->everyuser."\" --password=\"".$CONF->everypass."\" --host=\"".$CONF->everything_dbserv."\" everything");
