#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"), "Create new E2 API object");

# Attempt to create an e2node as guest
my $title = "Random new node ".time();
ok(my $result = $eapi->create_e2node({"title" => $title}), "Try for guest user to make a new e2node");
ok($result->{code} == 401, "Guest user cannot create an e2node");
ok($result = $eapi->get_node($title, "e2node"), "Try to get the newly created node");
ok($result->{code} == 404, "Attempted node creation doesn't exist");

ok($eapi->login("normaluser1","blah"), "Log in as normaluser1");
ok($result = $eapi->create_e2node({"title" => $title}), "Try for normaluser1 to make a new e2node");
ok($result->{code} == 200, "Creation returns 200 OK");

my $e2node = $result->{e2node};
ok($e2node->{author}->{title} eq "Content Editors", "New nodes are always owned by Content Editors under the hood");
ok($e2node->{title} eq $title, "The title comes back as correct");
ok($e2node->{createdby}->{title} eq "normaluser1", "New nodes have the display type of being created by the user that created them");

# Delete as normaluser1
ok($result = $eapi->delete_node($e2node->{node_id}), "Try to delete the e2node as normaluser1");
ok($result->{code} == 403, "Non-owner delete comes back as FORBIDDEN");

ok($eapi->logout, "Logging out");

# Delete as guest
ok($result = $eapi->delete_node($e2node->{node_id}), "Try to delete the e2node as guest");
ok($result->{code} == 403, "Non-owner delete comes back as FORBIDDEN"); 

# Delete as root
ok($eapi->login("root","blah"), "Log in as an admin");
ok($result = $eapi->delete_node($e2node->{node_id}), "Delete the e2node");
ok($result->{code} == 200, "Node was deleted successfully");
ok($result->{data}->{deleted} == $e2node->{node_id}, "Delete structure exists correctly");

done_testing;
