#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"), "Create new E2 API object");

ok(my $guest_vars = $eapi->developervars, "Get Guest Users Developer VARS");
ok($guest_vars->{code} == 401, "Guest VARS comes back as 403 Forbidden");

ok($eapi->login("normaluser1","blah"), "Log in as normaluser 1");
ok(my $normal_vars = $eapi->developervars, "Get Normaluser1 Developer VARS");
ok($normal_vars->{code} == 401, "Normal user VARS comes back as 403 Forbidden");

ok($eapi->login("genericdev","blah"), "Log in as genericdev");
ok(my $developer_vars = $eapi->developervars, "Get Normaluser1 Developer VARS");
ok($developer_vars->{code} == 200, "Genericdev VARS comes back as 403 Forbidden");

ok(exists($developer_vars->{data}->{nodelets}), "Sample VAR exists");

done_testing;
