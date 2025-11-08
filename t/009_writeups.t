#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything::APIClient;

ok(my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api"), "Create new E2 API object");

# Creation and valid key tests

ok($eapi->login("normaluser1","blah"), "Log in as normaluser 1");

my $title = "Testing title ".time();
my $writeuptype = "place";
my $doctext = "Test doctext";

ok($eapi->create_e2node({"title" => $title}), "Create a test e2node to work with");
my $data;
ok($data = $eapi->create_writeup({"title" => $title, writeuptype => $writeuptype, doctext => $doctext}), "Create a new writeup to work with"); 
ok($data->{code} == 200, "Can create a writeup successfully");
my $writeup = $data->{writeup};
my $valid_owner_keys = [qw|upvotes downvotes notnew reputation|];
my $valid_keys = [qw|doctext parent writeuptype author createtime node_id title type|];

foreach my $key (@$valid_owner_keys, @$valid_keys)
{
  ok(defined($writeup->{$key}), "$key is defined in the writeup for the owner");
}

ok($writeup->{notnew} == 0, "Writeup is the default with notnew = 0");
ok($writeup->{upvotes} == 0, "Upvotes is specifically listed and zero");
ok($writeup->{downvotes} == 0, "Downvotes is specifically listed and zero");

ok($writeup->{parent}->{title} eq $title, "The title is correct");
ok($writeup->{title} eq "$title ($writeuptype)", "The node title is correct");
ok($writeup->{doctext} eq $doctext, "The doctext is correct");
ok($writeup->{type} eq "writeup", "The type is correct");
ok($writeup->{author}->{title} eq "normaluser1", "The author reference is correct");

ok(scalar(@$valid_owner_keys) + scalar(@$valid_keys) == scalar(keys %$writeup), "There are no unknown keys");

ok($eapi->login("normaluser2","blah"), "Log in as normaluser2");
ok($data = $eapi->get_node_by_id($writeup->{node_id}), "Fetch the writeup not as the author");
ok($data->{code} == 200, "Node comes back okay as normaluser2");
$writeup = $data->{data};

foreach my $key (@$valid_keys)
{
  ok(defined($writeup->{$key}), "$key is defined in the writeup for the non-owner");
}

foreach my $key (@$valid_owner_keys)
{
  ok(!defined($writeup->{$key}), "$key is not defined in the writeup for the non-owner");
}

ok(scalar(@$valid_keys) == scalar(keys %$writeup), "There are no unknown non-owner keys");

# Bad delete test
my $writeup_id = $writeup->{node_id};
my $parent_id = $writeup->{parent}->{node_id};

## Normaluser2
ok($data = $eapi->delete_node($writeup_id), "Delete returns a data structure");
ok($data->{code} == 403, "Users are forbidden for API deletion of other people's writeups");

## Normaluser1
ok($eapi->login("normaluser1","blah"), "Log back in as normaluser1");
ok($data = $eapi->delete_node($writeup_id), "Try to delete as normaluser1");
ok($data->{code} == 403, "Users are forbidden from API deletion of their own writeups");

# Teardown of first test writeup
ok($eapi->login("root","blah"),"Log in as root");
ok($data = $eapi->delete_node($writeup_id), "Delete returns a data structure for root");
ok($data->{code} == 200, "Admins can API delete writeups");
ok($data = $eapi->get_node_by_id($writeup_id), "Deleted writeup returns data structure");
ok($data->{code} == 405, "Writeup doesn't exist");

# Add in notnew check
ok($eapi->login("normaluser1","blah"), "Log in normaluser1");
ok($data = $eapi->create_writeup({title => $title, writeuptype => $writeuptype, doctext => $doctext, notnew => 1}), "Try to create a writeup with notnew=1");
ok($data->{code} == 200, "Notnew creation returns ok request"); 
ok(defined($data->{writeup}->{node_id}), "Writeup structure comes back ok");
ok($data->{writeup}->{notnew} == 1, "Notnew is set");

$writeup_id = $data->{writeup}->{node_id};

# Guest user can't delete writeups
ok($eapi->logout, "Successfully log out");
ok($data = $eapi->delete_node($writeup_id), "Post a Guest User deletion request");
ok($data->{code} == 403, "Deleting a node as Guest User returns forbidden");

# Delete the notnew writeup
ok($eapi->login("root","blah"),"Log in as root");
ok($data = $eapi->delete_node($writeup_id), "Delete returns a data structure for root");
ok($data->{code} == 200, "Notnew writeup delete ok");

# Bad creation tests
ok($eapi->login("normaluser1","blah"), "Log in normaluser1");
ok($data = $eapi->create_writeup({writeuptype => $writeuptype, doctext => $doctext}), "Try to create a writeup without a title"); 
ok($data->{code} == 400, "Titleless writeup creation returns bad request"); 

ok($data = $eapi->create_writeup({title => $title, doctext => $doctext}), "Try to create a writeup without a title"); 
ok($data->{code} == 400, "Writeup without writeuptype returns bad request");

ok($data = $eapi->create_writeup({title => $title, writeuptype => $writeuptype}), "Try to create a writeup without a doctext"); 
ok($data->{code} == 400, "Writeup without doctype returns bad request");

ok($eapi->logout, "Log out of normaluser1, back to Guest User");
ok($data = $eapi->create_writeup({title => $title, writeuptype => $writeuptype, doctext => $doctext}), "Try to create a writeup without a title");
ok($data->{code} == 401, "Creating otherwise good writeup as Guest User returns unauthorized"); 



# Teardown of test e2node
ok($eapi->login("root","blah"), "Log in as root");
ok($data = $eapi->delete_node($parent_id), "Delete the parent node");
ok($data->{code} == 200, "Admins can API delete e2nodes");
ok($data = $eapi->get_node_by_id($parent_id), "Deleted node returns data structure");
ok($data->{code} == 405, "Parent e2node doesn't exist");

done_testing;
