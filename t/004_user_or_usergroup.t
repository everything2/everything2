#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $definitely_a_user = getNode("root","user");
my $definitely_a_usergroup = getNode("gods","usergroup");
my $definitely_a_superdoc = getNode("Message Inbox","superdoc");

ok($APP->isUser($definitely_a_user));
ok(! $APP->isUser($definitely_a_usergroup));
ok(! $APP->isUser($definitely_a_superdoc));

ok(! $APP->isUsergroup($definitely_a_user));
ok($APP->isUsergroup($definitely_a_usergroup));
ok(! $APP->isUsergroup($definitely_a_superdoc));

ok($APP->isUserOrUsergroup($definitely_a_user));
ok($APP->isUserOrUsergroup($definitely_a_usergroup));
ok(! $APP->isUserOrUsergroup($definitely_a_superdoc));

done_testing();
