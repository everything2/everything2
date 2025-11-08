#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Everything::APIClient;
use Test::More;

my $eapi = Everything::APIClient->new("endpoint" => "http://localhost/api");
my $description = "This is a description!<br>";
ok($eapi->login("root","blah"), "Log in as root");
ok(my $result = $eapi->create_usergroup({"title" => "My usergroup ".time(),"doctext" => $description}), "Usergroup create returns a non undef structure");

ok($result->{code} == 200, "200 OK returned from usergroup creation");
my $usergroup = $result->{usergroup};
ok($usergroup->{node_id} != 0, "Non-zero node_id is returned");
ok($usergroup->{doctext} eq $description, "Description matches what was passed");

# Description update
$description.= "A second line of text<br>";
ok($result = $eapi->update_node($usergroup->{node_id}, {"doctext" => $description}), "Update description field of usergroup");
ok($result->{code} == 200, "Result of update is 200 OK");
ok($result->{data}->{doctext} eq $description, "Document text got updated properly");

# User adding
ok(!exists($usergroup->{group}), "Group is empty");

ok(my $root = $eapi->get_node("root","user")->{data}, "Get user for root");
ok(my $nm1 = $eapi->get_node("normaluser1","user")->{data}, "Get user for normaluser1");
ok(my $nm2 = $eapi->get_node("normaluser2","user")->{data}, "Get user for normaluser2");

#Initial add
ok($result = $eapi->usergroup_add($usergroup->{node_id}, [$root->{node_id}]), "Add 'root' to the usergroup");
ok($result->{code} == 200, "Return code on the add is 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}||[]}) == 1, "There is one node in the group");
ok($usergroup->{group}->[0]->{node_id} == $root->{node_id}, "Root is in the group");

#Second add
ok($result = $eapi->usergroup_add($usergroup->{node_id}, [$nm1->{node_id}]), "Add 'normaluser1' to the usergroup");
ok($result->{code} == 200, "Return code on the add is 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}||[]}) == 2, "There are two nodes in the group");
ok($usergroup->{group}->[1]->{node_id} == $nm1->{node_id}, "Normaluser1 is in the group");

#Single remove
ok($result = $eapi->usergroup_remove($usergroup->{node_id}, [$nm1->{node_id}]), "Remove 'normaluser1' from the usergroup");
ok($result->{code} == 200, "Return code on the delete is 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}}) == 1, "There is one node in the group");
ok($usergroup->{group}->[0]->{node_id} == $root->{node_id}, "Root is in the group");

# Multi-add w/ duplicate
ok($result = $eapi->usergroup_add($usergroup->{node_id}, [$root->{node_id}, $nm1->{node_id}, $nm2->{node_id}]), "Multi-add with duplicates");
ok($result->{code} == 200, "Return code on the add is 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}}) == 3, "There are three nodes in the group");
ok($usergroup->{group}->[0]->{node_id} == $root->{node_id}, "Root is the first node");
ok($usergroup->{group}->[1]->{node_id} == $nm1->{node_id}, "Normaluser1 is the second node");
ok($usergroup->{group}->[2]->{node_id} == $nm2->{node_id}, "Normaluser2 is the third node");

# Multi-delete w/duplicate
for(0..1)
{
  # First time deletes, second time should be a no-op
  ok($result = $eapi->usergroup_remove($usergroup->{node_id}, [$root->{node_id}, $nm2->{node_id}, $nm2->{node_id}]), "Multi-delete with duplicates");
  ok($result->{code} = 200, "Return from delete is 200");
  $usergroup = $result->{data};
  ok(scalar(@{$usergroup->{group}}) == 1, "There is one node in the group");
  ok($usergroup->{group}->[0]->{node_id} == $nm1->{node_id}, "Only normaluser1 is left in the group");
}

ok($eapi->logout,"Log out of root");

# Guest user group add
ok($result = $eapi->usergroup_add($usergroup->{node_id}, [$root->{node_id}]), "Try to add as guest user");
ok($result->{code} == 403, "Return code is Forbidden");
ok($result = $eapi->get_node_by_id($usergroup->{node_id}), "Guest user gets the node by id");
ok($result->{code} == 200, "Guest user get by id returns 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}}) == 1, "There is one node in the group");
ok($usergroup->{group}->[0]->{node_id} == $nm1->{node_id}, "Only normaluser1 is left in the group");


# Non-owner add
ok($eapi->login("normaluser1","blah"), "Log in normaluser1");
ok($result = $eapi->usergroup_add($usergroup->{node_id}, [$root->{node_id}]), "Try to add as non-owner");
ok($result->{code} == 403, "Return code is Forbidden");
ok($result = $eapi->get_node_by_id($usergroup->{node_id}), "Normaluser1 gets the node by id");
ok($result->{code} == 200, "Guest user get by id returns 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}||[]}) == 1, "There is one node in the group");
ok($usergroup->{group}->[0]->{node_id} == $nm1->{node_id}, "Only normaluser1 is left in the group");

# Non-owner delete
ok($result = $eapi->delete_node($usergroup->{node_id}), "Attempt delete of non-owner usergroup");
ok($result->{code} == 403, "Non-owner delete returns Forbidden");
# Node is still there
ok($result = $eapi->get_node_by_id($usergroup->{node_id}), "Normaluser1 gets the node by id");
ok($result->{code} == 200, "Guest user get by id returns 200");
$usergroup = $result->{data};
ok(scalar(@{$usergroup->{group}||[]}) == 1, "There is one node in the group");

ok($eapi->logout, "Log out okay");
ok($eapi->login("root","blah"), "Log back in as root");

ok(my $output = $eapi->delete_node($usergroup->{node_id}), "Positive output from usergroup delete");
ok($output->{code} == 200, "Delete returns 200");
ok($output->{data}->{deleted} == $usergroup->{node_id}, "Deleted returns the right output");
ok($output = $eapi->get_node_by_id($usergroup->{node_id}), "Try to get the deleted node");
ok($output->{code} == 405, "No node returns unimplemented");



done_testing();
