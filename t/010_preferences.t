#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything::APIClient;

my $testpref = "vit_hidenodeinfo";
my $testpref2 = "vit_hidemisc";

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"), "Create new E2 API object");

ok(my $guest_prefs = $eapi->get_preferences, "Get Guest Users Preferences");
ok($guest_prefs->{code} == 200, "Guest get preferences comes back as 200 OK");
ok((defined($guest_prefs->{data}->{$testpref}) and ($guest_prefs->{data}->{$testpref} == 0)), "Sample guest user preference is zero");
ok(my $set_response = $eapi->set_preferences({$testpref => 1}), "Try to set a preference as guest");
ok($set_response->{code} == 401, "Guest gets unauthorized");

ok($set_response = $eapi->set_preferences({"collapsedNodelets" => "epicenter!"}), "Successful call of set_preference with a string pref as guest");
ok($set_response->{code} == 401, "Guest gets unauthorized also on string prefs");

ok($eapi->login("normaluser1","blah"), "Log in as normaluser 1");
ok($set_response = $eapi->set_preferences({$testpref => 1}), "Set a preference as normaluser1");
ok($set_response->{code} == 200, "Normaluser1 set preferences comes back as 200 OK");
ok($set_response->{data}->{$testpref} == 1, "Set worked correctly");

ok(my $get_response = $eapi->get_preferences, "Get preferences to check to make sure the update stuck");
ok($get_response->{code} == 200, "Normaluser1 get preferences comes back as 200 OK");
ok($get_response->{data}->{$testpref} == 1, "Set was committed");
ok($set_response = $eapi->set_preferences({"non_whitelisted_pref" => 1}), "Set a bad preference as normaluser1");
ok($set_response->{code} == 401, "Comes back as unauthorized");
ok($set_response = $eapi->set_preferences({$testpref => "badvalue"}), "Set a preference to a non-whitelisted value as normaluser1");
ok($set_response->{code} == 401, "Comes back as unauthorized");

ok($set_response = $eapi->set_preferences({$testpref => "badvalue", $testpref2 => 0}), "Setting mixed preferences");
ok($set_response->{code} == 401, "Comes back as unauthorized");

#FIXME: I don't know why I have to set it to space
foreach my $pref ("epicenter!","","epicenter!readthis!","epicenter!")
{
  ok($set_response = $eapi->set_preferences({"collapsedNodelets" => $pref}), "Setting string preferences to '$pref'");
  ok($set_response->{code} == 200, "Comes back as 200 OK");
  ok($set_response->{data}->{collapsedNodelets} eq $pref, "Setting string preference comes back correct as '$pref'");
  ok($get_response = $eapi->get_preferences, "Retrieve preferences to check for '$pref'");
  ok($get_response->{code} == 200, "Get pref comes back as 200 OK");
  ok($get_response->{data}->{collapsedNodelets} eq $pref, "String preference equals '$pref'");
}

done_testing;
