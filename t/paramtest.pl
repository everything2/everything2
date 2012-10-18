#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Data::Dumper;

initEverything 'everything';
#$APP->setParameter(getNode("root","user"),-1,"cancloak",1);
$APP->delParameter(getNode("root","user"),-1,"cancloak");

