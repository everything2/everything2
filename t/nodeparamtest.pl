#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Test::More qw(no_plan);

initEverything 'everything';

print "Testing!\n";

my $node = getNode("root","user");
my $result = $DB->getNodeParam($node, "foo");

ok(not defined($result));

$DB->setNodeParam($node, "foo", "bar");
$result = $DB->getNodeParam($node, "foo");

ok($result eq "bar");

$DB->setNodeParam($node, "foo", "bar2");
$result = $DB->getNodeParam($node, "foo");

ok($result eq "bar2");

$DB->deleteNodeParam($node,"foo");
$result = $DB->getNodeParam($node, "foo");

ok(not defined($result));

$DB->setNodeParam($node,"foo2","bird");
$DB->setNodeParam($node,"foo3","hello");

my $params = $DB->getNodeParams($node);

ok(scalar(keys %$params) == 2);
ok($params->{foo2} eq "bird");
ok($params->{foo3} eq "hello");

# Should be a no-op
$DB->deleteNodeParam($node,"foo");
