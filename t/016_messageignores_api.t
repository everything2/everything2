#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Test::Deep;
use Everything;
use Everything::APIClient;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

ok(my $eapi = Everything::APIClient->new(endpoint => "http://localhost/api"), "Create a new Everything::APIClient object");

ok(my $cme = $eapi->get_node("Cool Man Eddie", "user")->{data}, "CME fetch ok");
ok(my $virgil = $eapi->get_node("Virgil","user")->{data}, "Virgil fetch ok");
my $emptyignores = {"code" => 200, "messageignore" => []};

my $unauthorized = {"code" => 401};
my $ignored_eddie = {"code" => 200, "messageignore" => $Everything::APP->node_json_reference($cme)};
my $unignored_eddie = {"code" => 200, "messageignore" => [$cme->{node_id}]};
my $ignoring_only_eddie = {"code" => 200, "messageignore" => [$Everything::APP->node_json_reference($cme)]};

my $ignored_virgil = {"code" => 200, "messageignore" => $Everything::APP->node_json_reference($virgil)};
my $unignored_virgil = {"code" => 200, "messageignore" => [$virgil->{node_id}]};
my $ignoring_both = {"code" => 200, "messageignore" => [$Everything::APP->node_json_reference($cme), $Everything::APP->node_json_reference($virgil)]};

my $response;

# First as guest
cmp_deeply($eapi->get_ignores(), $unauthorized, "Guest: get list of ignores");
cmp_deeply($eapi->ignore_messages_from("root"), $unauthorized, "Guest: ignore messages from name (root)");
cmp_deeply($eapi->ignore_messages_from_id(113), $unauthorized, "Guest: ignore messages from id (root)");
cmp_deeply($response = $eapi->unignore_messages_from_id(113),$unauthorized,"Guest: unignore messages from id (root)");

foreach my $user("root","normaluser1")
{
  ok($response = $eapi->login($user,"blah"),"Login as $user");
  cmp_deeply($eapi->get_ignores(), $emptyignores,"Initial ignoring set is empty");
  cmp_deeply($eapi->ignore_messages_from("Cool Man Eddie"), $ignored_eddie, "Root: Ignore messages from CME");
  cmp_deeply($eapi->get_ignores(), $ignoring_only_eddie, "Root: Ignoring messages from CME"); 

  cmp_deeply($eapi->ignore_messages_from_id($virgil->{node_id}), $ignored_virgil, "Ignore messages from Virgil");
  cmp_deeply($eapi->get_ignores, $ignoring_both, "Currently ignoring 2 users");

  #Ignoring a second time should be okay
  cmp_deeply($eapi->ignore_messages_from_id($virgil->{node_id}), $ignored_virgil, "Ignore messages from Virgil, second time");
  cmp_deeply($eapi->get_ignores, $ignoring_both, "Currently ignoring 2 users");

  cmp_deeply($eapi->unignore_messages_from_id($virgil->{node_id}),$unignored_virgil, "Unignored messages from Virgil");
  cmp_deeply($eapi->get_ignores(), $ignoring_only_eddie, "Root: Ignoring messages from CME"); 
  
  cmp_deeply($eapi->unignore_messages_from_id($cme->{node_id}), $unignored_eddie, "Unignore CME");
  cmp_deeply($eapi->get_ignores(), $emptyignores,"Initial ignoring set is empty");

  #Unignore twice
  cmp_deeply($eapi->unignore_messages_from_id($cme->{node_id}), $unignored_eddie, "Unignore CME");
  cmp_deeply($eapi->get_ignores(), $emptyignores,"Initial ignoring set is empty");
}

done_testing();
