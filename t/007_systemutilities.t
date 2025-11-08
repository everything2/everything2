#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything::APIClient;

my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api");

# Guest
ok(my $result = $eapi->roompurge, "Room purge as guest");
ok($result->{code} == 403, "Room purge as guest is FORBIDDEN");

# Non-admin
ok($eapi->login("normaluser1","blah"), "Log in as a non-admin");
ok($result = $eapi->roompurge, "Purge as a non-admin");
ok($result->{code} == 403, "Non-admin roompurge returns 403");

ok($eapi->login("root","blah"), "Log in as an admin");
ok($result = $eapi->roompurge, "Purge as an admin");
ok($result->{code} == 200, "Purge returns 200 ok");

# Test to make sure we are getting a good result

foreach my $user("normaluser1","normaluser2","normaluser3","root")
{
  ok($eapi->login($user,"blah"), "Seed the rooms table by logging in as '$user'");
}

ok($result = $eapi->roompurge, "Purge as root");
ok($result->{code} == 200, "Purge as root returns OK");
ok($result->{data}->{purged} == 4, "Purge returns 4 purges");

done_testing();
