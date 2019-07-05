#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

ok(my $type = getNode("document","nodetype"));
ok(my $type2 = getType("document"));
ok($type->{node_id} eq $type2->{node_id});

my $data = {"doctext" => "This is my text"};
my $title = "new test document ".time();
# insertNode($title, $TYPE, $USER, $NODEDATA);
# returns a new nodeid
ok(my $newnode_id = $DB->insertNode($title, $type2, -1, $data));
ok(defined $newnode_id);
ok($newnode_id > 0);

ok(my $newnode = getNodeById($newnode_id));
ok($newnode->{node_id} eq $newnode->{document_id});
ok($newnode->{title} eq $title);

ok($DB->nukeNode($newnode, -1), "Get rid of test node");
done_testing();
