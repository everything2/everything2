#!/usr/bin/perl -w

use strict;
use lib qw(/root/everything2/ecore);
use Everything;

initEverything 'everything';

print "alex: (admin): ".$APP->userCanCloak(getNode("alex","user"))."\n";
print "illusionist: (param): ".$APP->userCanCloak(getNode("illusionist","user"))."\n";
print "e2med: (cloakers): ".$APP->userCanCloak(getNode("e2med","user"))."\n";
print "dannye (highlvl): ".$APP->userCanCloak(getNode("dannye","user"))."\n";
