#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More tests => 23;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $htmlcode = getNode("googleads", "htmlcode");
ok(defined($htmlcode->{node_id}), "Able to get 'googleads','htmlcode'");
ok(my $available_parameters = $APP->getParametersForType("htmlcode"), "Get available parameters for htmlcode");
ok(exists($available_parameters->{prevent_nuke}), "Prevent nuke exists on htmlcode");
ok($APP->setParameter($htmlcode, -1, "prevent_nuke", 1), "Can assign prevent_nuke to an htmlcode");
ok($APP->getParameter($htmlcode, "prevent_nuke") == 1, "Can get prevent_nuke from an htmlcode");
ok($APP->delParameter($htmlcode, -1, "prevent_nuke") == 1, "Can delete prevent_nuke from an htmlcode");

my $user = getNode("root", "user");
ok(defined($user->{node_id}), "Able to get 'root','user'");

my $refinfo = sub {my $i = shift; return (ref $i ne "")?(", by type hash"):(", by integer")}; 

foreach my $type("user", getType("user"))
{
	ok($available_parameters = $APP->getParametersForType($type), "Get available parameters for user".$refinfo->($type));
	ok(exists($available_parameters->{cancloak}), "cancloak exists on user".$refinfo->($type));
	ok(exists($available_parameters->{prevent_nuke}), "prevent_nuke exists on user".$refinfo->($type));
}

foreach my $item($user, $user->{node_id})
{
	ok($APP->setParameter($item, -1, "prevent_nuke", 1), "Can set prevent_nuke on a user".$refinfo->($item));
	ok($APP->getParameter($item, "prevent_nuke") == 1, "Can get prevent_nuke on a user".$refinfo->($item));
	ok($APP->delParameter($item, -1, "prevent_nuke") == 1, "Can delete prevent_nuke from user".$refinfo->($item));
	ok($APP->delParameter($item, -1, "cancloak"), "Delete cancloak, even when not set".$refinfo->($item));
	ok((not defined($APP->getParameter($item, "cancloak"))), "Cancloak is not set on the user".$refinfo->($item));
}
