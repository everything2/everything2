#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Everything;
initEverything 'everything';

my $actions = $APP->refreshRoomUsers;
foreach my $action (@$actions)
{
  print "action - $action->{action}, room - $action->{room}, user - $action->{user}\n";
}
