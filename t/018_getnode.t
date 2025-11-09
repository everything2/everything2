#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

# Test Basic fields for node that exists
ok(my $node = getNode("Message Inbox","superdoc"));
ok($node->{title} eq "Message Inbox");
ok($node->{type}->{title} eq "superdoc");
ok($node->{node_id} == $node->{document_id});

# Test cache poisoning behavior
ok($node->{title} = "Message Inbox 2");
ok(my $nid = getNodeById($node->{node_id}));
ok($nid->{title} eq "Message Inbox 2");

# Test force override behavior
ok($nid = getNodeById($node->{node_id}, "force"));
ok($nid->{title} = "Message Inbox");

done_testing();
