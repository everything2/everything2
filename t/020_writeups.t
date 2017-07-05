#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"), "Create new E2 API object");

ok($eapi->login("normaluser1","blah"), "Log in as normaluser 1");

my $title = "Testing title ".time();
ok($eapi->create_e2node({"title" => $title}), "Create a test e2node to work with");
my $data;
ok($data = $eapi->create_writeup({"title" => $title, writeuptype => "place", doctext => "Test doctext"}), "Create a new writeup to work with"); 
ok($data->{code} == 200, "Can create a writeup successfully");
ok($eapi->login("root","blah"), "Log in as root");

done_testing;
