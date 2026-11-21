#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Test::More tests => 5;
use diagnostics;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $long_enough = $Everything::CONF->logged_in_threshold+100;

$DB->executeQuery("DELETE from room");

# lasttime has one writer (Everything::Request); updateNode never writes it, so set it directly.
my $set_lasttime = sub {
  my ($u, $expr) = @_;
  $DB->sqlUpdate('user', { -lasttime => $expr }, "user_id=" . int($u->{node_id}));
};

my $cme = $DB->getNode("Cool Man Eddie","user");
$set_lasttime->($cme, "DATE_SUB(NOW(),INTERVAL $long_enough second)");
$APP->changeRoom($cme,0);

my $webby = $DB->getNode("Webster 1913","user");
$set_lasttime->($webby, "NOW()");

my $actions = $APP->refreshRoomUsers;
my $expected_results = [0,0];

foreach my $action(@$actions)
{
  $expected_results->[0] = 1 if($action->{room} == 0 and $action->{action} eq 'entrance' and $action->{user} == $webby->{user_id});
  $expected_results->[1] = 1 if($action->{room} == 0 and $action->{action} eq 'departure' and $action->{user} == $cme->{user_id});
}

ok($expected_results->[0] == 1, "Webby entered correctly");
ok($expected_results->[1] == 1, "CME left correctly");

my $pa = getNode("Political Asylum","room");
ok(exists($pa->{node_id}), "PA exists");

# We can't use changeRoom here because it updates room. We have to artificially time the user out
$set_lasttime->($cme, "NOW()");
$cme->{in_room} = $pa->{node_id};
$DB->updateNode($cme, -1);

$actions = $APP->refreshRoomUsers;
$expected_results = [0];

foreach my $action(@$actions)
{
  $expected_results->[0] = 1 if($action->{room} == $pa->{node_id} and $action->{action} eq 'entrance' and $action->{user} == $cme->{user_id});
}

ok($expected_results->[0] == 1, "CME entered PA correctly");

$set_lasttime->($cme, "DATE_SUB(NOW(),INTERVAL $long_enough second)");

$actions = $APP->refreshRoomUsers;
$expected_results = [0];

foreach my $action(@$actions)
{
  $expected_results->[0] = 1 if($action->{room} == $pa->{node_id} and $action->{action} eq 'departure' and $action->{user} == $cme->{user_id});
}

ok($expected_results->[0] == 1, "CME departed PA correctly");

